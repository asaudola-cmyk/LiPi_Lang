# Maya Roadmap — আকাঙ্ক্ষামূলক কোড (Aspirational Code)

এই ডিরেক্টরিতে মায়ার ভবিষ্যত পরিকল্পনার কোড আছে।
এগুলো এখনো কম্পাইল হয় না — এগুলো "vision documents" হিসেবে রাখা হয়েছে।

## ডিরেক্টরি:
- `universe/` — Standard Library (AI, Net, Crypto, OS, GUI, 3D)
- `compiler/` — Self-hosting compiler (মায়ায় লেখা)
- `tools/` — LSP, Formatter, Package Manager, Debugger
- `assimilator/` — Language transpilers (Python, C, JS → Maya)

## অবস্থা:
এগুলো মায়ার C++ কম্পাইলার দিয়ে কম্পাইল হয় না কারণ:
1. অনেক feature ব্যবহার করা হয়েছে যা কম্পাইলার এখনো support করে না
2. Object literal syntax, for-in over strings, closures ইত্যাদি নেই
3. Import system নতুন যোগ করা হয়েছে কিন্তু এই ফাইলগুলো আরো features দরকার
