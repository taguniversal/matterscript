# C & POSIX Code Generation

While VHDL generation targets spatial execution on reconfigurable hardware, the **C & POSIX Code Generation** backend lowers Invocation Language AST nodes into portable, deterministic ANSI C/POSIX software constructs. This allows space-time graph definitions to execute on conventional host operating systems and embedded processors.

## Architectural Mapping

The software backend translates spatial-temporal graph semantics into low-overhead POSIX primitives without modifying the core IPL syntax:

* **Resolutions → Threads / Tasks:** Top-level resolutions map directly to POSIX threads (`pthread_create`) or task routines.
* **Streams & Places → File Descriptors & Pipes:** Data paths between processing nodes are emitted as POSIX byte streams, non-blocking FIFOs (`mkfifo`), or Unix domain sockets.
* **Tokens & Signals → POSIX Synchronization:** Token passage across graph edges lowers to POSIX semaphores (`sem_t`), mutexes, or `poll`/`select` readiness checks to enforce deterministic signal flow.

```
+------------------------+        +---------------------------+
|    IPL AST Node        |        |    C / POSIX Target       |
+------------------------+        +---------------------------+
|  Resolution Node       |  --->  |  void* task_thread(void*) |
|  Stream / Data Place   |  --->  |  int pipe_fd[2]           |
|  Token / Signal Edge   |  --->  |  sem_t token_sem          |
+------------------------+        +---------------------------+

```

## Compilation Pipeline Steps

1. **AST lowering:** Flatten resolution graphs into explicit execution frames and state transitions.
2. **Buffer Allocation:** Bind data channels to fixed-size ring buffers or file descriptor handles to prevent runtime dynamic memory allocations (`malloc`).
3. **Thread Instantiation:** Synthesize main entry loops and initialize POSIX synchronization primitives (`pthread_mutex_init`, `sem_init`).
4. **Target Emission:** Output clean, dependency-free ANSI C code suitable for compilation via `gcc`, `clang`, or target cross-compilers.

## Target Attributes & Configuration

Low-level OS parameters that fall outside core language logic are specified directly via target attributes attached to nodes:

```ipl
$sensor_node() : [
    @target(posix, path="/dev/ttyS0", priority=100)
    dev< stream_in >
]

```

This ensures full portability across environments while allowing explicit control over OS resources, scheduling priorities, and file paths when compiling for standard Linux or embedded POSIX runtimes.

*Drafting in progress...*