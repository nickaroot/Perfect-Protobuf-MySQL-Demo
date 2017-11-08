import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import SwiftProtobuf
import Foundation
import PerfectMySQL

let testHost = "127.0.0.1"
let testUser = "root"
let testPassword = "secretproduct"
let testDB = "swift"

func fetchDataHandler(data: [String:Any]) throws -> RequestHandler {
 
    return {

        request, response in

        let mysql = MySQL() // Create an instance of MySQL to work with

        let connected = mysql.connect(host: testHost, user: testUser, password: testPassword)

        guard connected else {
            // verify we connected successfully
            print(mysql.errorMessage())
            return
        }

        defer {
            mysql.close() //This defer block makes sure we terminate the connection once finished, regardless of the result
        }

        //Choose the database to work with
        guard mysql.selectDatabase(named: testDB) else {
                Log.info(message: "Failure: \(mysql.errorCode()) \(mysql.errorMessage())")
                return
        }

        let stmt = MySQLStmt(mysql)

        _ = stmt.prepare(statement: "SELECT * FROM test")

        let querySuccess = stmt.execute()

        // make sure the query worked
        guard querySuccess else {
            print(mysql.errorMessage())
            return
        }

        // Save the results to use during this session
        let results = stmt.results()

        let fieldNames = stmt.fieldNames()

        var arrayResults: [[String:Any]] = []

        _ = results.forEachRow { row in

            var rowDictionary = [String: Any]()

            var i = 0

            while i != results.numFields {
                rowDictionary[fieldNames[i]!] = row[i]
                i += 1
            }

            arrayResults.append(rowDictionary)

        }

        print(arrayResults)

        response.setHeader(.contentType, value: "text/html")
        response.appendBody(string: "<html><title>Testing...</title><body>\(arrayResults)</body></html>")

        response.completed()
    }
}


func sendHandler(data: [String:Any]) throws -> RequestHandler {
    return {
        request, response in
        
        if !request.postParams.isEmpty {
            
            var name: String? = nil
            var id: Int32? = nil
            var email: String? = nil
            
            for param in request.postParams {
                if param.0 == "name" {
                    name = param.1
                } else if param.0 == "id" {
                    id = Int32(param.1)
                } else if param.0 == "email" {
                    email = param.1
                }
            }

            if let personName = name, let personId = id, let personEmail = email {
                var person = Person()
                person.name = personName
                person.id = personId
                person.email = personEmail

                do {
                    let data = try person.serializedData()
                    print("Serialized Proto into Data")
                    print("Sending Proto…")
                    ProtoSender().send(data)
                } catch {
                    print("Failed to Serialize Protobuf Object into Data")
                }
            }
        }
        
        response.setHeader(.contentType, value: "text/plain")
        response.appendBody(string: "1")

        response.completed()
    }
}

func receiveHandler(data: [String:Any]) throws -> RequestHandler {
    return {
        request, response in
        // Respond with a simple message.
        
        print("Proto Received!")

        if let bytes = request.postBodyBytes {
            let data = Data(bytes: bytes)

            do {
                let person = try Person(serializedData: data)
                print("Proto was received and converted into a person with: \nname: \(person.name) \nid: \(person.id) \nemail: \(person.email)")
                
                let mysql = MySQL() // Create an instance of MySQL to work with

                let connected = mysql.connect(host: testHost, user: testUser, password: testPassword)

                guard connected else {
                    // verify we connected successfully
                    print(mysql.errorMessage())
                    return
                }

                defer {
                    mysql.close() //This defer block makes sure we terminate the connection once finished, regardless of the result
                }

                guard mysql.selectDatabase(named: testDB) else {
                        Log.info(message: "Failure: \(mysql.errorCode()) \(mysql.errorMessage())")
                        return
                }

                let stmt = MySQLStmt(mysql)

                _ = stmt.prepare(statement: "INSERT INTO test (id, name, email) VALUES (?, ?, ?)")

                stmt.bindParam(Int(person.id))
                stmt.bindParam(person.name)
                stmt.bindParam(person.email)

                let querySuccess = stmt.execute()

                guard querySuccess else {
                    print(mysql.errorMessage())
                    return
                }
            } catch {
                print("Failed to Decode Proto")
            }
        }
        
        response.setHeader(.contentType, value: "text/plain")
        response.appendBody(string: "1")
        response.completed()
    }
}
