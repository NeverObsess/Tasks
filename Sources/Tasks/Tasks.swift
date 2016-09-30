//
//  Tasks.swift
//  Tasks
//
//  Created by Honza Dvorsky on 5/8/16.
//
//

import Foundation

public struct TaskResult {
    public let code: Int32
    public let stdout: Data
    public let stderr: Data
    
    public var stdoutStringUTF8: String {
        return (String(data: stdout, encoding: .utf8) ?? "").trimRight()
    }
    
    public var stderrStringUTF8: String {
        return (String(data: stderr, encoding: .utf8) ?? "").trimRight()
    }
}

public struct Task {
    
    public static func run(_ args: String...) throws -> TaskResult {
        return try run(args)
    }
    
    public static func run(_ args: [String], data: Data? = nil, pwd: String? = nil, inheritEnvironment: Bool = true) throws -> TaskResult {
        
        #if os(Linux)
        let task = Foundation.Task()
        #else
        let task = Foundation.Process()
        #endif
        
        var args = args
        
        if let pwd = pwd {
            task.currentDirectoryPath = pwd
        }
        
        let processInfo = ProcessInfo.processInfo
        task.environment = processInfo.environment
        task.launchPath = try which(args.removeFirst())
        task.arguments = args
        
        let stdout = Pipe()
        task.standardOutput = stdout
        let stdoutHandle = stdout.fileHandleForReading
        
        let stderr = Pipe()
        task.standardError = stderr
        let stderrHandle = stderr.fileHandleForReading
      
        if let data = data {
            let pipe = Pipe()
            pipe.fileHandleForWriting.write(data)
            pipe.fileHandleForWriting.closeFile()
            task.standardInput = pipe
        }
        task.launch()
        
        var stdoutData = Data()
        var stderrData = Data()
        
        let isRunning = { () -> Bool in
            #if os(Linux)
            return task.running
            #else
            return task.isRunning
            #endif
        }
        
        repeat {
            let newStdoutData = stdoutHandle.readDataToEndOfFile()
            if !newStdoutData.isEmpty {
                stdoutData.append(newStdoutData)
            }

            let newStderrData = stderrHandle.readDataToEndOfFile()
            if !newStderrData.isEmpty {
                stderrData.append(newStderrData)
            }
        } while isRunning()
        
        let result = TaskResult(code: task.terminationStatus, stdout: stdoutData, stderr: stderrData)
        return result
    }
}

extension Data {
    
    func pipedOutDataToString() -> String {
        return (String(data: self, encoding: String.Encoding.utf8) ?? "").trimRight()
    }
}

extension String {

    var isAbsolute: Bool { 
        return self.hasPrefix("/") 
    }
    
    func trimRight() -> String {
        let trimmableChars: Set<Character> = ["\n", "\r", "\t", " "]
        let count = characters.count
        var end: Int = count
        for (idx, char) in characters.reversed().enumerated() {
            if trimmableChars.contains(char) {
                end = count-idx-1
            } else {
                break
            }
        }
        let trimmed = self.substring(to: index(startIndex, offsetBy: end))
        return trimmed
    }
}

func which(_ tool: String) throws -> String {

    if tool.isAbsolute {
        return tool
    }
    let result = try Task.run("/usr/bin/which", tool)
    guard result.code == 0 else { throw TaskError("Failed to find tool \"\(tool)\"") }
    let path = result.stdoutStringUTF8
    return path
}

public struct TaskError: Error {

    public let description: String
    init(_ description: String) {
        self.description = description
    }
}


