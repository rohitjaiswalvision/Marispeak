import Foundation
import PushToTalk

if #available(iOS 16.0, *) {
    let err = PTChannelError(_nsError: NSError(domain: PTChannelErrorDomain, code: 6, userInfo: nil))
    print(err)
}
