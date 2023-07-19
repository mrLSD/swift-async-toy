import Combine
import Foundation

actor MsgQueue {
    var msg: String?
    var counter = 0

    func getMsg() async -> String? {
        defer { msg = nil }
        return msg
    }

    func run() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        counter += 1
        msg = "Counter [\(counter)]"
    }
}

actor Queue {
    var terminate = false
    var msgQueue: MsgQueue

    init(msgQueue: MsgQueue) {
        self.msgQueue = msgQueue
    }

    func terminating() async {
        terminate = true
    }

    func handler() -> AsyncStream<String> {
        AsyncStream { stream in
            Task {
                while !terminate {
                    if let msg = await msgQueue.getMsg() {
                        stream.yield(msg)
                        print("-> Data sent: \(msg)")
                    }
                }
                stream.finish()
            }
        }
    }

    func run() async {
        while !terminate {
            await msgQueue.run()
        }
    }

    func isTerminated() async -> Bool {
        terminate
    }
}

struct Runner {
    let runnerActor = MsgQueue()
    let queue: Queue

    init() {
        queue = Queue(msgQueue: runnerActor)
    }

    func run() async {
        Task {
            let stream = await queue.handler()
            for await msg in stream {
                print("<- Stream receive: \(msg)")
            }
            print("Stream has finished.")
        }
    }

    func stop() async {
        await queue.terminating()
    }
}

func aFunc1() async {
    var i = 0
    while i < 3 {
        print("aFunc1 \(i)")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        i += 1
    }
}

func aFunc2() async {
    var i = 0
    while i < 6 {
        print("aFunc2 \(i)")
        try? await Task.sleep(nanoseconds: 250_000_000)
        i += 1
    }
}

func runTasks(runner: Runner) async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            await aFunc1()
        }
        group.addTask {
            await aFunc2()
        }
        group.addTask {
            await runner.run()
        }
        group.addTask {
            await runner.queue.run()
        }
        group.addTask {
            while true {
                if await runner.runnerActor.counter == 10 {
                    break
                }
            }
            await runner.stop()
        }
    }
}

struct RequestMessage {
    var message: String
}

struct ResponseMessage {
    var message: String
}

struct MessageREQREP {
    let req = PassthroughSubject<RequestMessage, Never>()
    let rep = PassthroughSubject<ResponseMessage, Never>()

    func send(msg: String) {
        req.send(RequestMessage(message:msg))
    }
}

print("Run...")
let runner = Runner()
await runTasks(runner: runner)
print("Done")
