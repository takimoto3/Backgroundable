//
//  Test.swift
//  Backgroundable
//  
//  Created by Masato Takimoto on 2025/11/09.
//  
//

import MacroTesting
import Testing

#if canImport(BackgroundableMacros)
import BackgroundableMacros
#endif


@Suite("Backgroundable Property Macro Tests", .macros([BackgroundablePropertyMacro.self]))
struct BackgroundablePropertyTests {
    @Test("WithName") func withName() async throws {
        assertMacro{
            """
            @BackgroundableProperty(name: "bgTaskID")
            class Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            class Sample {
                func executeTask() {
                    print("hello")
                }

                private var _bgTaskID: UIBackgroundTaskIdentifier = .invalid
            }
            """
        }
    }
    @Test("NoArgs") func noArgs() async throws {
        assertMacro{
            """
            @BackgroundableProperty()
            class Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        } diagnostics: {
            """
            @BackgroundableProperty()
            ┬────────────────────────
            ╰─ 🛑 Required argument 'name' is missing in @BackgroundableProperty macro.
            class Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        }
    }
    @Test("WithStruct") func targetStruct() async throws {
        assertMacro{
            """
            @BackgroundableProperty()
            struct Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        } diagnostics: {
            """
            @BackgroundableProperty()
            ┬────────────────────────
            ╰─ 🛑 @BackgroundableProperty macro must be applied to a class.
            struct Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        }
    }
    @Test("WithActor") func targetActor() async throws {
        assertMacro{
            """
            @BackgroundableProperty()
            actor Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        } diagnostics: {
            """
            @BackgroundableProperty()
            ┬────────────────────────
            ╰─ 🛑 @BackgroundableProperty macro must be applied to a class.
            actor Sample {
                func executeTask() {
                    print("hello")
                }
            }
            """
        }
    }
}

@Suite("Backgroundable Macro Tests", .macros([BackgroundableMacro.self]))
struct BackgroundableTests {
    @Test("WithPropertyAndTaskName") func withPropertyAndTaskName() async throws {
        assertMacro{
            """
            class Sample {
                @Backgroundable(propertyName: "bgTaskID", withName:"Slow Task")
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            class Sample {
                func executeTask() {
                    self._bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "Slow Task") {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    defer {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    print("hello")
                }
            }
            """
        }
    }
    
    @Test("WithPropertyName") func withPropertyName() async throws {
        assertMacro{
            """
            class Sample {
                @Backgroundable(propertyName: "bgTaskID")
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            class Sample {
                func executeTask() {
                    self._bgTaskID = UIApplication.shared.beginBackgroundTask {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    defer {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    print("hello")
                }
            }
            """
        }
    }
    
    @Test("WithTaskName") func withTaskName() async throws {
        assertMacro{
            """
            class Sample {
                @Backgroundable(withName:"Slow Task")
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            class Sample {
                func executeTask() {
                    var _backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
                    _backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Slow Task") {
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    defer {
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    print("hello")
                }
            }
            """
        }
    }
    
    @Test("NoArgs") func noArgs() async throws {
        assertMacro{
            """
            struct Sample {
                @Backgroundable
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            struct Sample {
                func executeTask() {
                    var _backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
                    _backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    defer {
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    print("hello")
                }
            }
            """
        }
    }
    
    @Test("WithExpirationFunc") func withExpirationFunc() async throws {
        assertMacro{
            """
            struct Sample {
                @Backgroundable(expirationFunc:"cleanupTask")
                func executeTask() {
                    print("hello")
                }
            }
            """
        } expansion: {
            """
            struct Sample {
                func executeTask() {
                    var _backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
                    _backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                        self.cleanupTask()
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    defer {
                        if _backgroundTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(_backgroundTaskID)
                            _backgroundTaskID = .invalid
                        }
                    }
                    print("hello")
                }
            }
            """
        }
    }

    @Test("InvalidFunctionBody") func invalidFunctionBody() async throws {
        assertMacro{
            """
            protocol MyService {
                @Backgroundable
                func doSomething()
            }
            """
        } diagnostics: {
        """
        protocol MyService {
            @Backgroundable
            ┬──────────────
            ╰─ 🛑 @Backgroundable can only be applied to functions that have a body.
            func doSomething()
        }
        """
        }
    }            
}

@Suite(.macros([BackgroundableMacro.self, BackgroundablePropertyMacro.self]))
struct BackgroundableMacroTest {
    @Test func combinedMacroUsage() async throws {
        assertMacro {
            """
            @BackgroundableProperty(name: "bgTaskID")
            class MyService {
                @Backgroundable(propertyName: "bgTaskID", withName: "Combined Task")
                func runHeavyOperation() {
                    print("Running background work.")
                    // ... long running code ...
                }
            }
            """
        } expansion: {
            """
            class MyService {
                func runHeavyOperation() {
                    self._bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "Combined Task") {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    defer {
                        if self._bgTaskID != .invalid {
                            UIApplication.shared.endBackgroundTask(self._bgTaskID)
                            self._bgTaskID = .invalid
                        }
                    }
                    print("Running background work.")
                }

                private var _bgTaskID: UIBackgroundTaskIdentifier = .invalid
            }
            """
        }
    }
}
