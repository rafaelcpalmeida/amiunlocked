import Cocoa
import Just

private func getISOTimestamp() -> String {
    if #available(macOS 10.12, *) {
        let date = Date()
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: date)
    } else {
        fatalError("This process only runs on macOS 10.12+.")
    }
}

class Sync {
    private static let config = Config()
    
    enum SyncStatus {
        case pending(nextState: State)
        case success
        case failure(retryState: State)
    }
    
    var syncStatus: SyncStatus = .success
    private var task: DispatchWorkItem?
    
    func initializeSync(state: State) {
        syncStatus = .pending(nextState: state)
        handleSync()
    }
    
    private func handleSync() {
        if task != nil { task!.cancel() }
        
        switch syncStatus {
        case let .pending(nextState):
            executeAutomations(state: nextState)
        case .success:
            break
        case let .failure(retryState):
            syncStatus = .pending(nextState: retryState)
            executeAutomations(state: retryState)
        }
    }
    
    private func sendRequest(state: State, payload: Dictionary<String, Any>, action: String) {
        let r = Just.post(
            Sync.config.url + action,
            json: payload,
            headers: ["Authorization": "Bearer \(Sync.config.api_key)"]
        )
        if r.ok {
            NSLog("Network: request succeeded")
            syncStatus = .success
        } else {
            NSLog("Network: request failed")
            syncStatus = .failure(retryState: state)
            task = DispatchWorkItem { self.handleSync() }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2, execute: task!)
        }
    }
    
    private func executeAutomations(state: State) {
        let calendar = Calendar.current
        
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        let weekday = calendar.dateComponents([.weekday], from: startOfToday)
        
        if weekday.weekday! > 1 && weekday.weekday! < 7 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"
            
            Sync.config.automations.forEach{ automation in
                let automationParams = automation.value as! Dictionary<String, Any>
                
                let automationStarts = automationParams["starts"] as? String ?? ""
                let automationEnds = automationParams["ends"] as? String ?? ""
                let action = automationParams["action"] as? String ?? ""
                let automationState = automationParams["state"] as? String ?? ""
                let channel = automationParams["channel"] as? String ?? ""
                
                if automationStarts != "" && automationEnds != "" && action != "" {
                    let startTimeComponent = calendar.dateComponents([.hour, .minute], from: dateFormatter.date(from: automationStarts)!)
                    let endTimeComponent   = calendar.dateComponents([.hour, .minute], from: dateFormatter.date(from: automationEnds)!)
                    
                    let startTime    = calendar.date(byAdding: startTimeComponent, to: startOfToday)!
                    let endTime      = calendar.date(byAdding: endTimeComponent, to: startOfToday)!
                    
                    if startTime <= now && now <= endTime {
                        if state.rawValue == automationState {
                            switch action {
                            case "chat.postMessage":
                                var phrases = automationParams["phrases"] as? Array<String> ?? Array<String>()
                                var emojis = automationParams["emojis"] as? Array<String> ?? Array<String>()
                                
                                if phrases.count != 0 || emojis.count != 0 {
                                    phrases.shuffle()
                                    emojis.shuffle()
                                    
                                    let payload = ["channel": channel, "as_user": true, "text": "\(phrases.first!) \(emojis.first!)"] as [String : Any]
                                    
                                    sendRequest(state: state, payload: payload, action: action)
                                }
                            case "users.profile.set":
                                var phrases = automationParams["phrases"] as? Array<String> ?? Array<String>()
                                var emojis = automationParams["emojis"] as? Array<String> ?? Array<String>()

                                if emojis.count != 0 {
                                    phrases.shuffle()
                                    emojis.shuffle()
                                    
                                    let payload = ["profile": ["status_emoji": emojis.first, "status_text": phrases.first]] as [String : Any]
                                    
                                    sendRequest(state: state, payload: payload, action: action)
                                }
                            default:
                                print("Don't know what to do")
                            }
                        }
                    }
                }
            }
        }
    }
}
