#!/usr/bin/env python3
"""Build an independent baseline executable; SIGKILL the upgrade at durable boundaries.
All databases are disposable copies under .artifacts. Never touches the user's library.
"""
import hashlib
import json
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / ".artifacts" / "legacy-process-proof"
FIXTURE = ROOT / "Tests/LegacyMigrationTests/Fixtures"
BASE = "dd6fabb89368dd791800352e5ee006166fd88c73"
ARTIFACTS.mkdir(parents=True, exist_ok=True)


def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=True, **kwargs)


def baseline():
    package = ARTIFACTS / "baseline"
    source = package / "Sources/Muses"
    source.mkdir(parents=True, exist_ok=True)
    provenance = json.loads((FIXTURE / "provenance.json").read_text())
    # Exact original model-bearing files, fetched from the fixed integration baseline.
    for path, expected in provenance["modelSourceSHA256"].items():
        data = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)
        assert hashlib.sha256(data).hexdigest() == expected
        (source / pathlib.Path(path).name).write_bytes(data)
    for name in ["Enums.swift", "ListeningContext.swift", "EQBand.swift", "UserPreferences.swift"]:
        (source / name).write_bytes(subprocess.check_output(["git", "show", f"{BASE}:Sources/Muses/Domain/{name}"], cwd=ROOT))
    (source / "L10n.swift").write_bytes(subprocess.check_output(["git", "show", f"{BASE}:Sources/Muses/App/L10n.swift"], cwd=ROOT))
    # Only pure value helpers are separated from their original service source files.
    queue = run(["git", "show", f"{BASE}:Sources/Muses/Domain/QueueItem.swift"]).stdout
    (source / "QueueItem.swift").write_text(queue.split("    /// Sibling queue")[0] + "}\n")
    history = run(["git", "show", f"{BASE}:Sources/Muses/Services/History/HistoryService.swift"]).stdout
    (source / "RecapRange.swift").write_text("import Foundation\n" + history[history.index("enum RecapRange:"):])
    pagination = run(["git", "show", f"{BASE}:Sources/Muses/Services/YouTube/YouTubeDataAPIClient.swift"]).stdout
    (source / "Pagination.swift").write_text(pagination.split("/// YouTube Data API")[0])
    models = ["Track", "QueueState", "EQPreset", "YouTubeImport", "YouTubeImportItem", "Playlist", "PlaylistItem", "ListeningEvent", "ListeningSession", "InboxItem", "TrackNote", "TrackBookmark", "AutomationRule", "FocusSession", "CatalogRelease", "CatalogArtist", "YouTubePlaylistRevision", "YouTubeSyncOperation", "YouTubeSyncBatch"]
    counts = "\n".join(f'        counts["{m}"] = try context.fetchCount(FetchDescriptor<{m}>())' for m in models)
    (source / "BaselineMain.swift").write_text('''import Foundation
import SwiftData
@main struct BaselineMain {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        let url = URL(fileURLWithPath: args[1])
        let container = try ModelContainer(for: MusesSchema.current,
            configurations: [ModelConfiguration(schema: MusesSchema.current, url: url, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let track = try context.fetch(FetchDescriptor<Track>()).first!
        if args[2] == "edit" {
            track.title = "Baseline continued edit"
            context.insert(TrackNote(trackId: track.id, content: "Written by original baseline executable"))
            try context.save()
        }
        var counts: [String: Int] = [:]
''' + counts + '''
        let result: [String: Any] = ["models": counts, "title": track.title,
            "inverse": track.youTubeImportItems?.count ?? 0,
            "continuedEdit": try context.fetch(FetchDescriptor<TrackNote>()).contains { $0.content == "Written by original baseline executable" }]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), as: UTF8.self))
    }
}
''')
    (package / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "OriginalMusesBaseline", platforms: [.macOS(.v14)],
    products: [.executable(name: "OriginalMusesBaseline", targets: ["Muses"])],
    targets: [.executableTarget(name: "Muses")])
''')
    result = run(["swift", "build", "--package-path", str(package)])
    (ARTIFACTS / "baseline-build.log").write_text(result.stdout + result.stderr)
    binary_dir = run(["swift", "build", "--package-path", str(package), "--show-bin-path"]).stdout.strip()
    return pathlib.Path(binary_dir) / "OriginalMusesBaseline"


def seed(name):
    root = ARTIFACTS / name
    # Each run is independent; leave previous diagnostic directories intact.
    import uuid
    root = root.with_name(root.name + "-" + uuid.uuid4().hex)
    root.mkdir()
    for suffix in ["", "-wal", "-shm"]:
        shutil.copyfile(FIXTURE / ("original.store" + suffix), root / ("muses-youtube-native.sqlite" + suffix))
    return root


def fingerprint(root):
    return [hashlib.sha256((root / ("muses-youtube-native.sqlite" + s)).read_bytes()).hexdigest() for s in ["", "-wal", "-shm"]]


def invoke(executable, *args):
    result = run([str(executable), *map(str, args)])
    return json.loads(next(line for line in reversed(result.stdout.splitlines()) if line.startswith("{")))


def main():
    old = baseline()
    result = run(["swift", "build", "--product", "LegacyProcessHarness"])
    (ARTIFACTS / "harness-build.log").write_text(result.stdout + result.stderr)
    binary_dir = run(["swift", "build", "--show-bin-path"]).stdout.strip()
    new = pathlib.Path(binary_dir) / "LegacyProcessHarness"
    report = []
    for phase in ["snapshot", "beforeLegacyCommit", "legacyCommitted", "projected", "prepared", "activated"]:
        root = seed(phase)
        before = fingerprint(root)
        killed = subprocess.run([str(new), str(root), "route", phase], capture_output=True)
        assert killed.returncode == -9, (phase, killed.stderr.decode())
        assert fingerprint(root) == before
        resumed = invoke(new, root, "route")
        assert resumed["tracks"] == 1 and resumed["history"] == 1
        assert resumed["occurrences"] == 2 and resumed["playbackEntries"] == 2
        assert fingerprint(root) == before
        invoke(new, root, "edit")
        assert invoke(new, root, "route")["title"] == "Public edit survives restart"
        # Independent original-schema executable can write, then reopen and continue.
        rollback = invoke(old, root / "muses-youtube-native.sqlite", "edit")
        reopened = invoke(old, root / "muses-youtube-native.sqlite", "read")
        assert len(reopened["models"]) == 19 and all(reopened["models"].values())
        assert reopened["continuedEdit"] and reopened["title"] == "Baseline continued edit" and reopened["inverse"] == 2
        # Returning to public after editing the old library must surface the divergence.
        divergence = subprocess.run([str(new), str(root), "route"], capture_output=True)
        assert divergence.returncode != 0 and b"original library changed" in divergence.stderr
        failed_root = seed(phase + "-failed-rollback")
        failed = subprocess.run([str(new), str(failed_root), "route", phase], capture_output=True)
        assert failed.returncode == -9
        invoke(old, failed_root / "muses-youtube-native.sqlite", "edit")
        failed_reopened = invoke(old, failed_root / "muses-youtube-native.sqlite", "read")
        assert failed_reopened["continuedEdit"] and failed_reopened["inverse"] == 2
        report.append({"phase": phase, "killed": True, "restarted": resumed, "writableRollback": rollback, "divergenceBlocked": True, "failedWritableRollback": failed_reopened})
        print("PASS", phase, flush=True)
    for phase in ["deletionMarked", "deletionPurged"]:
        root = seed(phase)
        invoke(new, root, "route")
        command = "delete"
        if phase == "deletionPurged":
            invoke(new, root, "delete")
            command = "route"
        killed = subprocess.run([str(new), str(root), command, phase], capture_output=True)
        assert killed.returncode == -9
        cleared = invoke(new, root, "route")
        assert cleared["tracks"] == 0 and cleared["archiveTracks"] == 0 and not cleared["cleanupPending"]
        assert not any(root.glob("muses-youtube-native.sqlite*"))
        assert invoke(new, root, "route")["tracks"] == 0
        attempt_root = root / "muses-public-v1.sqlite.upgrade"
        assert len([p for p in attempt_root.iterdir() if p.is_dir()]) == 1
        invoke(new, root, "new-track")
        edited = invoke(new, root, "route")
        assert edited["tracks"] == 1 and edited["title"] == "New data after deletion" and edited["archiveTracks"] == 0
        selected = pathlib.Path(edited["target"])
        selected.unlink()
        missing = subprocess.run([str(new), str(root), "route"], capture_output=True)
        assert missing.returncode != 0 and not selected.exists()
        report.append({"phase": phase, "noResurrection": True, "oldFilesRemoved": True,
                       "newEditsPreserved": True, "missingNewStoreFailsClosed": True})
        print("PASS", phase, flush=True)
    root = seed("external-cleanup-pending")
    invoke(new, root, "route")
    killed = subprocess.run([str(new), str(root), "delete-external", "deletionMarked"], capture_output=True)
    assert killed.returncode == -9
    blocked = subprocess.run([str(new), str(root), "route"], capture_output=True)
    assert blocked.returncode != 0 and b"cleanupRequired" in blocked.stderr
    completed = invoke(new, root, "finish-external")
    assert completed["tracks"] == 0 and completed["archiveTracks"] == 0 and not completed["cleanupPending"]
    assert not any(root.glob("muses-youtube-native.sqlite*"))
    report.append({"state": "external-cleanup-pending", "restartBlockedUntilCleanup": True})
    print("PASS external cleanup pending blocks startup until completion", flush=True)
    (ARTIFACTS / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PASS independent original executable + 8 process termination boundaries")

if __name__ == "__main__":
    main()
