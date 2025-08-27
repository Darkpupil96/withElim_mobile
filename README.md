# withElim Mobile

**withElim Mobile** is a Flutter-based Bible reading and prayer app that provides a lightweight, clean, and cross-platform Scripture reading experience.  
The app supports multiple Bible versions and includes book/chapters navigation, quick switching, and prayer linking (planned).

---

## Features

- **Bible Reading**: Read Scriptures by book and chapter.  
- **Chapter Navigation**: Tap a book name to expand its chapters; switch between chapters easily.  
- **Multi-language Support**: Managed by `LangController` (currently supports KJV English & Chinese Union).  
- **Search Bar UI**: Built-in search bar (UI ready, logic to be implemented).  
- **Async Loading**: Chapter content is fetched with `FutureBuilder`, with proper loading & error states.  
- **Cross-platform**: Runs on both iOS and Android using Flutter.  

---

## Tech Stack

- **Flutter** (Dart) — Cross-platform mobile framework  
- **Material Design** — UI design system  
- **HTTP** — Fetching Bible content  
- **Provider / Controller Pattern** — Global state management (e.g. language)  

---

## Project Structure

lib/
├── main.dart # Entry point of the app
├── home.dart # Home screen (root navigation)
├── bible.dart # Bible reading screen (books & chapters)
├── search_bar.dart # Search bar UI component
├── app_lang.dart # Language controller (global state management)


## Getting Started

1. **Clone the repository**
   git clone https://github.com/Darkpupil96/withElim_mobile.git
   cd withElim_mobile
Install dependencies

flutter pub get
Run the app

flutter run

Roadmap / TODO
 Implement search logic (UI is in place)

 Add prayer records and link them with verses

 Improve chapter navigation interactions

 Add user login & personalization features

 Support for Dark Mode

License
This project is intended for learning and personal use only. Not for commercial distribution.
