import QtQuick
import Quickshell.Io

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property string state: "loading"
    property string error: ""
    property var races: []
    property var details: ({})
    property string fetchedAt: ""
    property bool loading: worker.running
    property var queue: []
    property var watched: []
    property var lastRequests: ({})
    property string currentPath: ""
    property string output: ""
    property int refreshIntervalSec: 60
    property double nextAllowed: 0
    property double overviewDue: 0
    property bool demo: false

    function enqueue(path) {
        if (demo || Date.now() < nextAllowed) return
        var key = path || "overview"
        if ((worker.running && currentPath === path) || queue.indexOf(path) >= 0) return
        var finished = path && races.some(function(r) {return r.path === path && r.status === "finished"})
        if (Date.now() - Number(lastRequests[key] || 0) < (finished ? 300000 : 60000)) return
        queue = queue.concat([path]).slice(0, 5)
        runNext()
    }
    function watch(path) {
        if (!/^race\/[a-z0-9-]+\/\d{4}\/(result|stage-\d+[a-z]?)$/.test(path)) return
        watched = [path].concat(watched.filter(function(p) { return p !== path })).slice(0, 3)
        enqueue(path)
    }
    function refresh() {
        enqueue("")
        for (var i = 0; i < watched.length; i++) enqueue(watched[i])
    }
    function runNext() {
        if (worker.running || !queue.length || demo || Date.now() < nextAllowed) return
        currentPath = queue[0]
        queue = queue.slice(1)
        var times = Object.assign({}, lastRequests)
        times[currentPath || "overview"] = Date.now()
        lastRequests = times
        output = ""
        var script = decodeURIComponent(Qt.resolvedUrl("bin/pcs.py").toString().replace(/^file:\/\//, ""))
        worker.command = currentPath ? ["/usr/bin/python3", "-I", script, "race", "--race", currentPath]
                                     : ["/usr/bin/python3", "-I", script, "overview"]
        if (currentPath && races.some(function(r) {return r.path === currentPath && r.status === "finished"}))
            worker.command = worker.command.concat(["--finished"])
        worker.running = true
    }
    function consume(code) {
        if (demo) return
        var result
        try { result = JSON.parse(output) } catch (e) { result = {state: "error", error: "Race data helper failed."} }
        if (code !== 0) result = {state: "error", error: "Race data helper could not run. Check Python 3 is installed."}
        if (currentPath) {
            var next = Object.assign({}, details)
            if (result.state === "ready") next[currentPath] = result
            else {
                var previous = next[currentPath] || ({})
                next[currentPath] = Object.assign({}, previous, {state:result.state, error:result.error})
            }
            details = next
        } else {
            state = result.state
            error = result.error || ""
            if (state === "ready" || state === "empty") {
                races = result.races || []
                fetchedAt = result.fetchedAt || ""
                overviewDue = Date.now() + 300000
                var paths = races.map(function(r) {return r.path})
                watched = watched.filter(function(p) {return paths.indexOf(p) >= 0})
                var retained = {}
                for (var i = 0; i < paths.length; i++) if (details[paths[i]]) retained[paths[i]] = details[paths[i]]
                details = retained
            }
        }
        var failureState = result.resultsState || result.state
        if (["blocked", "rate-limited"].indexOf(failureState) >= 0) {
            nextAllowed = Date.now() + 900000
            queue = []
        } else if (["offline", "error", "unsupported"].indexOf(result.state) >= 0 && !currentPath) {
            nextAllowed = Date.now() + 300000
            queue = []
        }
        Qt.callLater(runNext)
    }
    // Explicit fictional demo; never selected automatically on network failure.
    function setDemo(enabled) {
        if (worker.running) return false
        queue = []
        demo = enabled
        details = ({})
        races = []
        fetchedAt = ""
        error = ""
        watched = []
        lastRequests = ({})
        nextAllowed = 0
        if (enabled) demoFile.reload()
        else { state = "loading"; refresh() }
        return true
    }
    FileView {
        id: demoFile
        path: Qt.resolvedUrl("demo/fixtures/example.json").toString().replace(/^file:\/\//, "")
        onLoaded: {
            if (!root.demo) return
            try {
                var fixture = JSON.parse(text())
                root.races = fixture.races
                root.details = fixture.details
                root.state = "ready"
                root.fetchedAt = new Date().toISOString()
            } catch (e) { root.state = "error"; root.error = "Demo fixture could not be loaded." }
        }
    }
    Process {
        id: worker
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.output = text }
        onExited: function(code, status) { root.consume(code) }
    }
    Timer {
        interval: Math.max(60, Math.min(900, root.refreshIntervalSec)) * 1000
        running: !root.demo
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() >= root.overviewDue) root.enqueue("")
            for (var i=0; i<root.watched.length; i++) root.enqueue(root.watched[i])
        }
    }
    IpcHandler {
        target: "io.github.vip32.procyclingstats"
        function refresh(): void { root.refresh() }
        function demo(enabled: bool): bool { return root.setDemo(enabled) }
        function open(): void { if (root.shell) root.shell.summon("io.github.vip32.procyclingstats", "{}") }
        function close(): void { if (root.shell) root.shell.hide("io.github.vip32.procyclingstats") }
        function status(): string {
            return JSON.stringify({state:root.state,error:root.error,loading:root.loading,demo:root.demo,
                                   races:root.races.length,details:Object.keys(root.details),fetchedAt:root.fetchedAt})
        }
    }
}
