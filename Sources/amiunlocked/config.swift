import Configuration
import Foundation

// Start a configuration manager, load configuration from an adjacent
// `config.json` file, cast config values to appropriate types, and
// fail if required config values are not present
struct Config {
    var url: String
    var api_key: String
    
    var automations = Dictionary<String, Any>()

    init() {
        let fileManager = FileManager.default
        let path = fileManager.currentDirectoryPath
        let manager = ConfigurationManager()
        
        manager.load(file: "\(path)/config.json")
        url = manager["url"] as? String ?? ""
        api_key = manager["api_key"] as? String ?? ""
        
        let automationsArray = manager["automations"] as? Array<Any> ?? Array<Any>()
        
        automationsArray.forEach{ automationItem in
            let automationObject = automationItem as? Dictionary<String, Any> ?? Dictionary<String, Any>()
            
            automationObject.forEach{ automation in
                if automation.key != "" {
                    automations[automation.key] = automation.value
                }
            }
        }
    
        if url == "" {
            fatalError("The config parameter 'url' is required. Set it in 'config.json' and please try again.")
        }
        
        if api_key == "" {
            fatalError("The config parameter 'api_key' is required. Set it in 'config.json' and please try again.")
        }
    }
}
