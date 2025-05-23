# Mamadoko iOS App

This is an iOS implementation of the "ママはひだりから数えてなんばんめ？" counting game, which challenges players to find the "mama" character at a specified position counting from the left.

## Features

- WebView-based implementation that wraps the HTML/JavaScript game
- Sound effects for correct and incorrect answers
- Haptic feedback support
- Scrolling support for high stage numbers (83+)
- Visual highlighting for the target character

## Requirements

- Xcode 14.0+
- iOS 15.0+
- Swift 5.0+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/daiokawa/mamadoko.git
   ```

2. Open the Xcode project:
   ```bash
   cd mamadoko/ios
   open Mamadoko.xcodeproj
   ```

3. Select a development team in the project settings if you want to run on a physical device.

4. Build and run the project in Xcode.

## How to Play

1. The game will show a line of characters (mostly emoji) with one "mama" (🙋‍♀️) character.
2. The prompt at the top asks which position the "mama" is, counting from the left.
3. Tap the correct number at the bottom of the screen.
4. If correct, you'll hear a sound and advance to the next stage.
5. If incorrect, you'll hear a different sound and can try again.
6. The game gets progressively harder with more characters appearing.

## Technical Details

- Built using WKWebView to render the HTML/JavaScript game
- Uses WKScriptMessageHandler for JavaScript-to-Swift communication
- Implements AVAudioPlayer for sound playback
- Uses UINotificationFeedbackGenerator for haptic feedback
- Features CSS-based scrolling with overflow properties for high stages

## License

This project is open source and available under the [MIT License](../LICENSE).