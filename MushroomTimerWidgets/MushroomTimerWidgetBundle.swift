import SwiftUI
import WidgetKit

@main
struct MushroomTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLogWidget()
        MushroomLiveActivity()
    }
}
