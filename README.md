# 🎬 CineList – Smart Movie & Series Tracker

CineList is a modern **Flutter-based movie & web series tracking app** designed to help users organize, manage, and discover content effortlessly — inspired by platforms like Netflix & Letterboxd.

---

## 🚀 Features

* 📂 **Folder-based Organization**
  Create custom folders to group movies and series

* 🎥 **Movies & Web Series Tracking**
  Add, edit, and manage your watchlist easily

* 🔥 **Smart Pick System**
  Get random suggestions from your collection

* ⭐ **IMDb Ratings Integration**
  View ratings directly in the app

* 🧾 **Franchise Tracking**
  Manage movie franchises in one place

* 🗑️ **Swipe to Delete**
  Clean and intuitive UI interactions

* 📊 **Statistics Dashboard**
  Track your watching habits

* 🌐 **Public Watchlist Sharing** *(Planned / In Progress)*

---

## 🖼️ Screenshots

> Add your app screenshots here

```
assets/screenshots/home.png  
assets/screenshots/folders.png  
assets/screenshots/detail.png  
```

---

## 🛠️ Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Supabase
* **Database:** PostgreSQL (via Supabase)
* **API:** TMDB (for movie data)
* **State Management:** (Add if using Provider / Riverpod etc.)

---

## 📦 Installation

1. Clone the repository:

```bash
git clone https://github.com/AkhilPothuraju/cinelist-app.git
```

2. Navigate to project:

```bash
cd cinelist-app
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

---

## ⚙️ Configuration

* Add your **TMDB API key**
* Configure **Supabase URL & anon key**

Example:

```dart
const supabaseUrl = "YOUR_URL";
const supabaseKey = "YOUR_KEY";
```

---

## 📁 Project Structure

```
lib/
 ├── auth/
 ├── folders/
 ├── movies/
 ├── series/
 ├── franchise/
 ├── services/
 ├── utils/
 └── widgets/
```

---

## 🔮 Upcoming Features

* ✅ Drag & drop reordering
* ✅ Folder progress tracking (watched/total)
* ⏳ Advanced recommendations system
* ⏳ Social sharing & profiles

---

## 🤝 Contributing

Contributions are welcome!
Feel free to fork the repo and submit pull requests.

---

## 📄 License

This project is currently not licensed.

---

## 👨‍💻 Author

**Akhil Pothuraju**

* GitHub: https://github.com/AkhilPothuraju

---

## ⭐ Support

If you like this project, consider giving it a star ⭐ on GitHub!
