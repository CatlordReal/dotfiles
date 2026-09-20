# C++ runner

Use Space then `rf` to compile and run the current C++ file with `g++` and C++20. Use Space then `rp` for the project runner, or `:CppRunProject` from any buffer. Space then `rs` opens preferences (`:CppRunSettings`). Other file types keep their existing runners.

File preferences let you choose the compiler executable, C++ standard, compiler flags and program arguments. On macOS, `/usr/bin/g++` is Apple's compiler driver; select a GNU compiler executable in preferences if you have installed one.

`CppRunFile` saves the current C++ buffer, compiles from its parent directory with argv passed directly to a terminal job, then runs only that successful build. Each binary has a unique cache path, so a failed compile cannot execute an older binary. Successful compile windows close before the program window opens.

`CppRunSettings` keeps compiler, standard, flags, and program arguments separate from project preferences. Edits use a draft and save only after the final prompt. Project settings are stored in Neovim's state directory, never in the project. `CppRunProject` opens project preferences when no root exists, then runs after save. Before build it saves modified buffers below that configured root.

Set the root plus explicit build and run argv lists there. Runner preferences come from your Neovim state; requested builds use the project's CMakeLists.txt or Makefile as usual. CMake always runs `cmake -S <root> -B <build_dir> -DCMAKE_BUILD_TYPE=<type>` before `cmake --build <build_dir>` and supports an optional target. Make and custom modes run only configured argv. Comma-separated fields represent argv items, not shell syntax.

The integrated terminal shows compiler and program output. Relative run commands containing `/` resolve below configured project root. CMake executable paths, Make run commands, and custom argv still need explicit configuration.
