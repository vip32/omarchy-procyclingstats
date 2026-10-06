import QtQuick
import QtTest
import "../../Model.js" as Model
TestCase {
    name:"PersistedPins"
    QtObject {id:source;property list<string> pins:["race/example/2026","race/example/2026/stage-2","invalid"]}
    function test_host_sequence_restores_edition_pins() {
        var settings=Model.settings({pinnedRaces:source.pins})
        compare(settings.pinnedRaces.length,1)
        verify(Model.isPinned("race/example/2026/gc",settings.pinnedRaces))
        compare(Model.togglePin("race/example/2026/stage-1",settings.pinnedRaces).length,0)
    }
}
