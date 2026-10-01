# C++ runner

Use Space then `rf` to compile and run the current C++ file with `g++` and C++20. Use Space then `rp` for the project runner, or `:CppRunProject` from any buffer. Space then `rs` opens preferences (`:CppRunSettings`). Other file types keep their existing runners.

File preferences let you choose the compiler executable, C++ standard, compiler flags and program arguments. On macOS, `/usr/bin/g++` is Apple's compiler driver; select a GNU compiler executable in preferences if you have installed one.

`CppRunFile` saves the current C++ buffer, compiles from its parent directory with argv passed directly to a terminal job, then runs only that successful build. Each binary has a unique cache path, so a failed compile cannot execute an older binary. Successful compile windows close before the program window opens.

`CppRunSettings` keeps compiler, standard, flags, and program arguments separate from project preferences. Edits use a draft and save only after the final prompt. Project settings are stored in Neovim's state directory, never in the project. `CppRunProject` opens project preferences when no root exists, then runs after save. Before build it saves modified buffers below that configured root.

On first project run, choose **g++ (no build directory)** or **CMake (creates build/ automatically)**. The g++ option discovers project C++ sources and writes its executable to Neovim's cache. If the project has multiple entry points, open the one to run. Source scanning excludes hidden, build, and vendor directories and has explicit size/depth limits. Projects with complex source selection should use their build system.

CMake always runs `cmake -S <root> -B <build_dir> -DCMAKE_BUILD_TYPE=<type>` before `cmake --build <build_dir>`, creates the build directory, and can infer a single `add_executable` target. Make and custom modes run configured argv. Comma-separated preference fields represent argv items, not shell syntax.

For direct g++ builds, Qt headers in source files or nearby quoted headers trigger `pkg-config` discovery for Qt Core, Gui, and Widgets. Qt6 is preferred, with Qt5 as a fallback. Compiler flags precede sources and linker libraries follow them. This does not run Qt's `moc`, `uic`, or resource compiler: use CMake for `Q_OBJECT`, UI/resource generation, other Qt modules, or unrelated libraries.

The integrated terminal shows compiler and program output. Relative run commands containing `/` resolve below configured project root. Nonstandard CMake executable paths, Make run commands, and custom argv still need explicit configuration.
