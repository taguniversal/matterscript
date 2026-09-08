# Web GPU Compute

Targeting WGSL: AST-to-WGSL translation, handling memory layout and @workgroup_size.

Buffer & Pipeline Abstractions: Mapping state memory to storage buffers (@binding) and managing ping-pong passes.

Execution & Dispatch: Setting up compute pipelines, dispatching workgroups, and handling headless vs. visual execution.

Headless Data Readback: Staging buffers and asynchronous GPU-to-CPU state extraction.

*Drafting in progress...*