# 🎯 Compositor

**Modern scorekeeping app for board games with beautiful interface and extensive customization**

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.8+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-UI%20Framework-purple.svg)

## ✨ Features

### 🎮 Game Modes
- **Pairs (2 teams)** - perfect for team games
- **Free for All (4 players)** - for competitions between multiple participants
- **Score modes 365 and 101** - classic board games

### 🎨 Scoreboard Customization
Choose from 4 unique styles:
- **📍 Classic** - traditional wooden design
- **🪨 Stone** - durable stone texture
- **💡 Neon** - bright neon style with green glow
- **🌳 Wooden** - natural wood with warm tones

### 🌍 Multilingual Support
- 🇷🇺 Russian
- 🇬🇧 English  
- 🇦🇿 Azerbaijani

### 📊 Game History
- Save results of all games
- Detailed statistics for each session
- Session winner tracking
- Delete unwanted entries

### 🎯 Smart Features
- **Shake to reset** - just shake your phone to reset scores
- **Carry over tens** - automatic carry when row is filled
- **Adaptive interface** - support for different screen sizes
- **Settings persistence** - your preferences are remembered

## 🚀 Quick Start

### Requirements
- iOS 15.0+
- Xcode 14.0+
- Swift 5.8+

### Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/Compositor.git
cd Compositor
```

2. Open the project in Xcode:
```bash
open Compositor.xcodeproj
```

3. Select device or simulator and run the project

## 📱 Usage

### Basic Functions
1. **Select game mode** - Pairs or Free for All
2. **Customize scoreboard style** in settings
3. **Count scores** by swiping beads
4. **Complete games** and track history

### Score Management
- **Swipe left** - move bead to active zone
- **Swipe right** - return bead to inactive zone
- **Shake phone** - reset all scores
- **"End Game" button** - finish current game

### Game History
- View all played games
- Detailed session information
- Winner determination by total wins

## 🏗️ Project Architecture

### Core Components
- **ContentView.swift** - main screen with game logic
- **GameSessionDetailView.swift** - detailed session information
- **HistoryView.swift** - game history
- **SettingsView.swift** - app settings

### Key Features
- **MVVM architecture** with SwiftUI
- **@AppStorage** for settings persistence
- **Localized strings** for multilingual support
- **Custom components** for reusable elements

## 🎨 Design & Interface

### Scoreboard Styles
Each style has unique visual characteristics:
- Frame gradients and textures
- Bead colors (active/inactive)
- Shadows and glows
- Special effects for neon style

### Animations
- Smooth transitions between states
- Spring animations for bead movement
- Visual feedback on interaction

## 🔧 Technical Details

### Data Structure
```swift
struct GameHistoryEntry {
    let date: Date
    let matchMode: MatchMode
    let gameMode: GameMode
    let scores: [Int]
    let names: [String]?
    let winner: Int?
    let totalWins: [Int]?
    let gameSessions: [GameSession]?
}
```

### Settings
- Match mode (pairs/free for all)
- Score display mode (per team/shared board)
- Scoreboard style (classic/stone/neon/wooden)
- Interface language

## 🤝 Contributing

We welcome contributions to the project! To make changes:

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ for board game enthusiasts**

![App Icon](Compositor/Assets.xcassets/AppIcon.appiconset/Gemini_Generated_Image_qjr5a0qjr5a0qjr5%20(1).png)

