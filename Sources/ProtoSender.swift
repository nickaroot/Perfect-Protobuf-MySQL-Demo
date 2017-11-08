import Foundation
import PerfectCURL

struct ProtoSender {
    func send(_ data: Data) {
        
        let url = "http://localhost:8181/receive"

        do {
            _ = try CURLRequest(url, .failOnError, .postData(Array(data))).perform()
        } catch {
            print("Sending failed")
        }
        
    }
}
