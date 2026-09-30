import XCTest
@testable import MusesNetworking

final class ConfigurationErrorTests: XCTestCase {
    func testGoogleErrorInfoOverridesGenericForbiddenWithoutLeakingMetadata() throws {
        let body = Data(#"{"error":{"code":403,"message":"Requests blocked: secret-fixture-key","errors":[{"reason":"forbidden"}],"details":[{"@type":"type.googleapis.com/google.rpc.Help","links":[]},{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"API_KEY_IOS_APP_BLOCKED","domain":"googleapis.com","metadata":{"consumer":"projects/secret-fixture-project","service":"youtube.googleapis.com","iosBundleId":"fixture.bundle"}}]}}"#.utf8)
        let error = try XCTUnwrap(APIError.classify(HTTPResponse(status: 403, body: body)))
        XCTAssertEqual(error, .configuration(.appNotAuthorized))
        XCTAssertTrue(error.localizedDescription.contains("not authorized"))
        XCTAssertTrue(error.localizedDescription.contains("Google API configuration"))
        XCTAssertTrue(error.localizedDescription.contains("retry"))
        XCTAssertTrue(error.localizedDescription.contains("open this content in YouTube"))
        XCTAssertFalse(error.localizedDescription.contains("secret-fixture"))
        XCTAssertFalse(String(describing: error).contains("secret-fixture"))
    }

    func testServiceDisabledAndInvalidKeyForGoogleAndLegacyResponses() {
        for (status, reason, expected) in [
            (403, "SERVICE_DISABLED", APIConfigurationIssue.serviceDisabled),
            (400, "API_KEY_INVALID", .invalidKey),
            (400, "API_KEY_EXPIRED", .invalidKey),
            (403, "API_KEY_SERVICE_BLOCKED", .appNotAuthorized)
        ] {
            let body = Data("{\"error\":{\"details\":[{\"@type\":\"type.googleapis.com/google.rpc.ErrorInfo\",\"reason\":\"\(reason)\"}]}}".utf8)
            XCTAssertEqual(APIError.classify(HTTPResponse(status: status, body: body)), .configuration(expected))
        }
        for (reason, expected) in [("accessNotConfigured", APIConfigurationIssue.serviceDisabled), ("keyInvalid", .invalidKey), ("ipRefererBlocked", .appNotAuthorized)] {
            let body = Data("{\"error\":{\"errors\":[{\"reason\":\"\(reason)\"}]}}".utf8)
            XCTAssertEqual(APIError.classify(HTTPResponse(status: 403, body: body)), .configuration(expected))
        }
    }

    func testUnknownDetailsAndRawMessageDoNotInventConfigurationFailure() {
        for body in [
            #"{"error":{"message":"API_KEY_IOS_APP_BLOCKED","errors":[{"reason":"forbidden"}]}}"#,
            #"{"error":{"details":[{"@type":"type.googleapis.com/google.rpc.Help","reason":"API_KEY_IOS_APP_BLOCKED"}],"errors":[{"reason":"forbidden"}]}}"#,
            #"{"error":{"details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"UNKNOWN_NEW_REASON"}],"errors":[{"reason":"forbidden"}]}}"#
        ] {
            XCTAssertEqual(APIError.classify(HTTPResponse(status: 403, body: Data(body.utf8))), .forbidden(reason: "forbidden"))
        }
        let quota = Data(#"{"error":{"errors":[{"reason":"quotaExceeded"}],"details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"RATE_LIMIT_EXCEEDED"}]}}"#.utf8)
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 403, body: quota)), .quotaExceeded(reason: "quotaExceeded"))
        XCTAssertNil(APIError.classify(HTTPResponse(status: 200, body: quota)))
        XCTAssertEqual(APIError.classify(HTTPResponse(status: 403, body: Data("invalid".utf8))), .forbidden(reason: nil))
    }
}
