#!/usr/bin/env python3
"""Only disposable physical fixtures. Verify actual successor SIGKILL + restart behavior."""
import sys
sys.dont_write_bytecode = True
import importlib.util
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("legacyproof", ROOT / "scripts/test-legacy-process-upgrade.py")
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)
proof.ARTIFACTS = ROOT / ".artifacts/archive-successor-process"
proof.ARTIFACTS.mkdir(parents=True, exist_ok=True)
contracts = json.loads((ROOT / "docs/archive-source-contracts.json").read_text())
import hashlib
for path, digest in contracts["reviewedSourceSHA256"].items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, "Source contract changed: " + path
result = proof.run(["swift", "build", "--product", "LegacyProcessHarness"])
(proof.ARTIFACTS / "build.log").write_text(result.stdout + result.stderr)
exe = pathlib.Path(proof.run(["swift", "build", "--show-bin-path"]).stdout.strip()) / "LegacyProcessHarness"
report = []
for phase in ["intent", "beforeSave", "saved", "verified", "activated"]:
    root = proof.seed(phase)
    original = proof.fingerprint(root)
    edited = proof.invoke(exe, root, "successor-edits")
    parent = pathlib.Path(edited["target"])
    killed = subprocess.run([str(exe), str(root), "successor", phase], capture_output=True)
    assert killed.returncode == -9, (phase, killed.stderr.decode())
    assert proof.fingerprint(root) == original and parent.exists()
    if phase != "activated":
        blocked = subprocess.run([str(exe), str(root), "route"], capture_output=True)
        assert blocked.returncode != 0, "pending must not fall back to parent"
    resumed = proof.invoke(exe, root, "successor")
    assert resumed["successor"] and resumed["archiveTracks"] == 0
    assert resumed["notes"] == ["Current user note"]
    assert resumed["playlistName"] == "Current user playlist" and resumed["playbackEntries"] == 2
    assert proof.fingerprint(root) == original and parent.exists()
    inventory = proof.invoke(exe, root, "successor-inventory")
    assert any(row["role"] == "active-successor" for row in inventory["retainedArtifacts"])
    assert any(row["role"] == "protected-original-or-recovery" for row in inventory["retainedArtifacts"])
    (root / "candidate-review.json").write_text(json.dumps({"candidate": resumed, **inventory}, indent=2) + "\n")
    proof.invoke(exe, root, "successor-delete")
    after = proof.invoke(exe, root, "route")
    assert after["tracks"] == 0 and after["notes"] == [] and after["playbackEntries"] == 0
    forbidden = subprocess.run([str(exe), str(root), "successor-restore"], capture_output=True)
    assert forbidden.returncode != 0
    # Explicit preparation retry also returns the authoritative edited generation, never the old plan.
    assert proof.invoke(exe, root, "successor")["tracks"] == 0
    candidate = pathlib.Path(after["target"])
    candidate.rename(candidate.with_suffix(".missing-test"))
    missing = subprocess.run([str(exe), str(root), "route"], capture_output=True)
    assert missing.returncode != 0 and not candidate.exists()
    assert proof.fingerprint(root) == original and parent.exists()
    report.append({"phase": phase, "sigkill": True, "userEditsAndOccurrencesPreserved": True,
                   "deletedItemsNotRestored": True, "missingSuccessorFailsClosed": True,
                   "originalMainWALSHMUnchanged": True, "parentRetained": True})
    print("PASS", phase, flush=True)
root = proof.seed("explicit-delete-after-successor")
proof.invoke(exe, root, "successor")
killed = subprocess.run([str(exe), str(root), "delete", "deletionMarked"], capture_output=True)
assert killed.returncode == -9
empty = proof.invoke(exe, root, "route")
assert empty["tracks"] == 0 and not empty["successor"] and not empty["cleanupPending"]
assert not any(root.glob("muses-youtube-native.sqlite*"))
assert not (root / "muses-public-v1.sqlite.upgrade/successor-active.json").exists()
report.append({"wholeAppDeletionTakesPriority": True, "successorControlsRemovedOnlyAfterExplicitDeletion": True})
reviewRoot = proof.seed("reviewable-candidate")
proof.invoke(exe, reviewRoot, "successor-edits")
reviewCandidate = proof.invoke(exe, reviewRoot, "successor")
reviewInventory = proof.invoke(exe, reviewRoot, "successor-inventory")
identity = json.loads((reviewRoot / "muses-public-v1.sqlite.upgrade/successor-active.json").read_text())
(reviewRoot / "candidate-review.json").write_text(json.dumps({"candidate": reviewCandidate, "activation": identity, **reviewInventory}, indent=2) + "\n")
report.append({"reviewableCandidate": str(reviewRoot / "candidate-review.json"), "currentStore": reviewCandidate["target"]})
(proof.ARTIFACTS / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS all five successor process termination boundaries")
