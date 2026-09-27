pragma Singleton
import QtQuick
QtObject {
    property var commands: []
    function execDetached(args) { commands = commands.concat([args]) }
}
