//
//  RestClient.swift
//  rft
//
//  Created by Levente Vig on 2018. 09. 29..
//  Copyright © 2018. Levente Vig. All rights reserved.
//

import Alamofire
import Foundation
import SwiftyJSON

protocol Networking {
    static func getTopList(for difficulty: DifficultyLevel,  with delegate: TopListDelegate)
	static func getExercises(for difficulty: DifficultyLevel, with delegate: GameDelegate)
	static func login(with username: String, password: String, with delegate: LoginDelegate)
}

class RestClient: Networking {

    // MARK: Singleton
    static let shared = RestClient()
    private init() {}

	private var headers = [
		"Authorization": "Token \(UserDefaults.standard.value(forKey: Constants.UserDefaultsKeys.token) ?? "")",
		"Content-Type": "application/json"
	]

	// MARK: - Manage

	static func updateToken(to newToken: String) {
		self.shared.headers["Authorization"] = "Token \(newToken)"
	}

    // MARK: - Login methods

	static func login(with username: String, password: String, with delegate: LoginDelegate) {
		let url = "\(Constants.kBaseURL)/login"
		let params = ["username": username, "password": password]
		shared.get(url: url,
				   with: params,
				   useToken: false,
				   method: .post,
				   success: { response in
			var loggedInUser = MyUser()
			loggedInUser.name = response["name"].stringValue
			loggedInUser.email = response["email"].stringValue
			loggedInUser.token = response["token"].stringValue
			delegate.loginDidSuccess(response: loggedInUser)
		}, fail: { error in
			delegate.loginDidFail(with: error)
		})
	}

	static func register(with username: String, password: String, email: String, with delegate: LoginDelegate) {
		let params = ["username": username, "password": password, "email": email]
		shared.get(url: "\(Constants.kBaseURL)/register",
			with: params,
			useToken: false,
			method: .post,
			success: { response in
				var loggedInUser = MyUser()
				loggedInUser.name = response["name"].stringValue
				loggedInUser.email = response["email"].stringValue
				loggedInUser.token = response["token"].stringValue

				delegate.loginDidSuccess(response: loggedInUser)
		}, fail: { error in
			delegate.loginDidFail(with: error)
		})
	}

    // MARK: - TopList methods

    /**
     Fetches the users' data for a selected level from the backend service.
     - Parameter difficulty : The difficulty level for loading results
     - Parameter delegate : The delegate which implements the `TopListDelegate` protocol
     */
    static func getTopList(for difficulty: DifficultyLevel, with delegate: TopListDelegate) {
		shared.get(url: "\(Constants.kBaseURL)/toplist?difficulty=\(difficulty.rawValue)",
			with: nil,
			useToken: true,
			method: .get,
			success: { response in

			var users: [MyUser] = []
			for user in response["users"] {
				let myUser = MyUser(json: user.1)
				users.append(myUser)
			}
			delegate.getTopListDidSuccess(users: users)
		}, fail: { error in
			delegate.getTopListDidFail(error: error)
		})
    }

    // MARK: - Exercises
	static func getExercises(for difficulty: DifficultyLevel, with delegate: GameDelegate) {
		shared.get(url: "\(Constants.kBaseURL)/tasks?difficulty=\(difficulty.rawValue)",
			with: nil,
			useToken: true,
			method: .get,
			success: { response in
				var exercises: [Exercise] = []
				for exercise in response {
					let myExercise = Exercise(json: exercise.1)
					exercises.append(myExercise)
				}
				delegate.getExercisesDidSuccess(exercises: exercises)
		}, fail: { error in
			delegate.getExercisesDidFail(with: error)
		})
    }

	static func post(_ result: GameResult, for difficulty: DifficultyLevel, with delegate: GameDelegate) {

		let url = "\(Constants.kBaseURL)/results?difficulty=\(difficulty.rawValue)"
		let time = result.time
		let correctAnswers = result.correctAnswers
		let params = ["time": time, "correct_answer": correctAnswers] as [String : Any]

		shared.get(url: url,
				   with: params, useToken: true,
				   method: .post,
				   success: nil,
				   fail: nil)
	}

	// MARK: - Template

	private func get(url: String, with data: [String: Any]?, useToken: Bool, method: HTTPMethod, success: ((JSON) -> Void)?, fail: ((Error) -> Void)?) {
		let head: [String: String]
		if useToken {
			head = headers
		} else {
			head = ["Content-Type": "application/json"]
		}
		Alamofire.request(url,
						  method: method,
						  parameters: data,
						  encoding: JSONEncoding.default,
						  headers: head)
			.validate(statusCode: 200..<300)
			.responseJSON { response in
			print("Request: \(String(describing: response.request))")   // original url request
			print("Response: \(String(describing: response.response))") // http url response
			print("Result: \(response.result)")                         // response serialization result

			if let error = response.error {
				NSLog("⚠️ \(error)")
				if let fail = fail {
					fail(error)
				}
				return
			}

			if let json = response.result.value {
				print("✅ JSON: \(json)") // serialized json response
				if let success = success {
					success(JSON(json))
				}
			}
		}
	}
}
