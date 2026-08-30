# Embedded POSIX Runtimes & Apache NuttX

While general POSIX targets rely on full Linux or BSD operating system abstractions, embedded microkernels enforce strict resource bounds and zero-dynamic-memory constraints. **Apache NuttX** serves as a primary embedded target for Invocation Language (IPL), offering standard POSIX API compliance with low memory footprints and real-time execution guarantees across microcontrollers and RISC-V/ARM architectures.

## Architecture & System Layering

The NuttX backend lowers IPL graphs into bare-metal POSIX C modules compiled directly into NuttX task images or Flat/Protected mode ELF binaries.

```
+-------------------------------------------------------+
|                IPL Execution Graph                    |
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|          C / POSIX AST Code Generation                |
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|            NuttX RTOS Adaptor Layer                   |
|  - POSIX Pthreads (`pthread_create`, `pthread_yield`) |
|  - Message Queues (`mq_open`, `mq_send`, `mq_receive`)|
|  - Character Driver Endpoints (`/dev/ttyS0`, `/dev/spi`)|
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|     Bare-Metal Hardware / Embedded Substrate          |
|    (ESP32, HiFive RISC-V, ARM Cortex-M, STM32)        |
+-------------------------------------------------------+

```

## Semantics Mapping

NuttX provides standard POSIX primitives, allowing IPL graph structures to map directly to RTOS constructs without requiring heavy OS abstraction layers:

* **Resolutions → NuttX Tasks / Pthreads:** Top-level space-time resolutions instantiate as lightweight `pthread` nodes configured with fixed thread stack sizes and static priority levels.
* **Streams → POSIX Message Queues (`mqd_t`) / FIFOs:** Token streams between processing nodes lower to POSIX message queues (`mq_send`/`mq_receive`) or native NuttX driver endpoints (`/dev/chanN`), bypassing user/kernel context switches in flat-build environments.
* **Token Placement → Named Semaphores (`sem_t`):** Deterministic token passage along graph edges maps directly to POSIX counting semaphores (`sem_wait`/`sem_post`), ensuring strict real-time ordering.

## Memory & Resource Allocation Strategy

Unlike desktop POSIX runtimes, the NuttX code generator enforces deterministic resource bounds to meet embedded real-time requirements:

1. **Zero Dynamic Allocation (`malloc`-free):** All message queue buffers, task stacks, and token state structs are statically allocated at compile time in `.bss` or specialized RAM regions.
2. **Fixed Task Priorities:** Execution nodes declare priority levels through target attributes to prevent priority inversion under the NuttX FIFO scheduler.
3. **Hardware Device Binding:** IPL input/output nodes interface directly with NuttX device paths (`/dev/sensor0`, `/dev/can0`) via standard `open()`, `read()`, `write()`, and `ioctl()` POSIX calls.

## Example IPL Domain Attribute Binding

NuttX-specific execution attributes are declared directly on IPL nodes using standard target annotations:

```ipl
$motor_control_loop() : [
    @target(nuttx, stack_bytes=4096, priority=200, sched="fifo")
    ctrl< stream_in >
    
    @target(posix, path="/dev/pwm0")
    actuator< stream_out >
]

```

*Drafting in progress...*