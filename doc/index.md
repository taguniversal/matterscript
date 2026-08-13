# MatterScript & Invocation Language Literate Development Architecture

## 1. Executive Summary

This document specifies the project layout, literate programming pipeline, asset management strategy, and toolchain orchestration for the **Invocation Language** and **MatterScript** development ecosystem. 

The core philosophy combines **Literate Programming (`.il.md` / `.ms.md`)** for co-locating natural language, network topologies, geometric placement, and executable specifications, using **Zig (`build.zig`)** as the unified master orchestrator across compilation, simulation, and editor extensions.

---

## 2. Repository Layout & Project Structure

To maintain modularity across the compiler, runtime OS, hardware verification, and VS Code extension domains, the repository follows a strict domain-isolated sub-package structure:

```
my_project/
├── src/
│   ├── adder.md                         # Primary Literate Source File
│   └── adder.assets/                    # Assets paired explicitly to adder.md
│       ├── static/                      # STATIC (Hand-edited, committed to Git)
│       │   ├── block_diagram.svg        # Hand-drawn architecture (Exhaust/Draw.io)
│       │   └── fpga_die_layout.png      # Reference hardware screenshot
│       │
│       └── generated/                   # DYNAMIC (Generated during weave, gitignored)
│           ├── fig_1_cytoscape.svg      # Rendered topology graph from ```cytoscape
│           ├── fig_2_waveform.svg       # Rendered Verilator timing trace
│           └── fig_3_mesh_render.png    # Rendered MeshLab 3D placement geometry
│
├── .gitignore
└── build.zig
```
Why this prevents a mess:
1) Scope Locality: Deleting or renaming adder.md means you know exactly which asset folder (adder.assets/) to delete or rename with it.

2) Clean Import Paths: Inside adder.md, static image links remain local and relative:

```
![Hardware Layout](./adder.assets/static/fpga_die_layout.png)
```

## Linking Dynamic Weave Artifacts Back into the Position
When your Zig Weaver processes adder.md to produce the final output (HTML, PDF, or rendered Markdown Preview), it needs to insert generated images back into the document without polluting your original source .md file with hardcoded image links.

Use Named Fenced Block Comments or Directive Attributes:

In your source Markdown (src/adder.md):
```
## Process Network Topology

Below is the execution network lowering step:

```il-topology { id="fig_1_cytoscape", caption="Lowered NCL Network" }
definition ADDER [
    (A_0, B_0) -> S_0 ;
]
```

#### How the Weaver Handles it:
When running `zig build weave` or rendering in VS Code:
1. The weaver reads the block `id="fig_1_cytoscape"`.
2. It executes Cytoscape / Verilator in the background and saves the vector output to `./adder.assets/generated/fig_1_cytoscape.svg`.
3. In the **woven output** (HTML/PDF or VS Code Webview DOM), the weaver transforms the code block into an inline figure containing both the original code *and* the rendered vector image immediately below it:

```html
<div class="literate-block">
  <pre><code class="language-il">definition ADDER ...</code></pre>
  <figure>
    <img src="./adder.assets/generated/fig_1_cytoscape.svg" alt="Lowered NCL Network">
    <figcaption>Figure 1: Lowered NCL Network</figcaption>
  </figure>
</div>
```

4. VS Code Webview Live-Sync Workflow
To make this seamless while editing in VS Code:

Virtual DOM / Memory Rendering during Dev:
When editing in VS Code, your extension's Webview host doesn't even need to write SVG files to disk. Cytoscape.js or WebGL (Three.js for MeshLab geometries) can render the interactive graph in-memory directly inside the Webview panel using webview.postMessage().

Disk Generation during CI / Build (zig build weave):
When running a head-less build to publish documentation (e.g., generating HTML/PDF for your team or repository docs site), the Zig build system calls CLI utilities (headless Puppeteer, resvg-cli, or MeshLab batch commands) to bake those in-memory models into flat .svg files in *.assets/generated/.

##  Compiler Pipeline: Tangling, Weaving, and Code Synchronization
The Zig compiler toolchain (matterc) natively parses both raw .il / .ms files and literate .il.md / .ms.md documents through dual execution pipelines:

```
┌──────────────────────┐
               │  adder.il.md Source  │
               └──────────┬───────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
   ┌─────────────────┐         ┌─────────────────┐
   │ Tangle Pipeline │         │ Weave Pipeline  │
   └────────┬────────┘         └────────┬────────┘
            │                           │
            ▼                           ▼
  Extracts ```il Fences      Parses Fenced Attributes
  Maps Byte Spans to AST      Executes Cytoscape / Verilator
            │                           │
            ▼                           ▼
  Generates AST/VHDL          Injects Generated Figures
  Executes on NuttX/WSL       Outputs Final HTML/PDF Docs
  ```

  A. Tangling (zig build tangle)
Scans the literate document for fenced code blocks tagged with ```il, ```matterscript, or ```invocation.

Strips surrounding Markdown prose while preserving exact line offsets and source span coordinates (SourceLocation).

Passes the extracted code directly into the Zig parser, ensuring error messages point precisely to the correct line in the original Markdown file.

B. Weaving (zig build weave)
Scans for custom directive attributes on code blocks, such as:

```
```il-topology { id="fig_adder_net", caption="Lowered Dual-Rail NCL Network" }
definition ADDER [
    ($A$B)(SUM<>) SUM <$A$B()> |
    $A$B() : 00:0 01:1 10:1 11:0
]
```

During headless documentation builds, the weaver processes the block, generates fig_adder_net.svg inside adder.il.assets/generated/, and embeds an inline figure into the output HTML or PDF.

## VS Code Webview Telemetry & Live Sync Architecture
During active development inside VS Code, dynamic asset generation happens in-memory for zero latency:

```
┌────────────────────────┐      IPC / Sockets       ┌────────────────────────┐
│  Runtime Binary        │ ───────────────────────► │ VS Code Extension Host │
│  (NuttX RTOS / WSL)    │  (JSON Token Telemetry)  │ (TypeScript Backend)   │
└────────────────────────┘                          └───────────┬────────────┘
                                                                │
                                                      webview.postMessage()
                                                                │
                                                                ▼
                                                    ┌────────────────────────┐
                                                    │ VS Code Webview Panel  │
                                                    │ (Cytoscape.js / WebGL) │
                                                    └────────────────────────┘
                               
 ```
1. Code -> Graph Selection: Moving the editor cursor in .il.md triggers vscode.window.onDidChangeTextEditorSelection. The extension host identifies the AST place/invocation at that line and highlights the matching node in Cytoscape.

1. Graph -> Code Navigation: Clicking a node or wire in the Cytoscape Webview panel posts a message back to VS Code to reveal the source line via vscode.TextEditor.revealRange().

1. Live Execution Telemetry: When running the network on Apache NuttX or WSL, runtime token movements ({"type": "TOKEN_FLOW", "from": "A_0", "to": "S_0"}) stream over a local TCP socket into the extension host and animate in Cytoscape in real time.

## Cytoscape.js Graph Topology Specification
Below is an embedded Cytoscape JSON payload representing a Null Convention Logic (NCL) Dual-Rail Adder Topology. This block can be directly parsed by the VS Code extension host and rendered inside the Cytoscape Webview panel.

```
{
  "elements": {
    "nodes": [
      {
        "data": {
          "id": "def_adder",
          "label": "definition ADDER",
          "type": "definition"
        }
      },
      {
        "data": {
          "id": "src_a0",
          "label": "$A_0 (Dest Place)",
          "parent": "def_adder",
          "type": "dest_place"
        }
      },
      {
        "data": {
          "id": "src_a1",
          "label": "$A_1 (Dest Place)",
          "parent": "def_adder",
          "type": "dest_place"
        }
      },
      {
        "data": {
          "id": "src_b0",
          "label": "$B_0 (Dest Place)",
          "parent": "def_adder",
          "type": "dest_place"
        }
      },
      {
        "data": {
          "id": "src_b1",
          "label": "$B_1 (Dest Place)",
          "parent": "def_adder",
          "type": "dest_place"
        }
      },
      {
        "data": {
          "id": "inv_ncl_gate",
          "label": "TH22 Threshold Gate",
          "parent": "def_adder",
          "type": "invocation"
        }
      },
      {
        "data": {
          "id": "dst_sum0",
          "label": "SUM_0<> (Source Place)",
          "parent": "def_adder",
          "type": "source_place"
        }
      },
      {
        "data": {
          "id": "dst_sum1",
          "label": "SUM_1<> (Source Place)",
          "parent": "def_adder",
          "type": "source_place"
        }
      }
    ],
    "edges": [
      {
        "data": {
          "id": "e_a0_gate",
          "source": "src_a0",
          "target": "inv_ncl_gate",
          "label": "Token Rail 0"
        }
      },
      {
        "data": {
          "id": "e_b0_gate",
          "source": "src_b0",
          "target": "inv_ncl_gate",
          "label": "Token Rail 0"
        }
      },
      {
        "data": {
          "id": "e_gate_sum0",
          "source": "inv_ncl_gate",
          "target": "dst_sum0",
          "label": "Resolved Token"
        }
      },
      {
        "data": {
          "id": "e_a1_gate",
          "source": "src_a1",
          "target": "inv_ncl_gate",
          "label": "Token Rail 1"
        }
      },
      {
        "data": {
          "id": "e_b1_gate",
          "source": "src_b1",
          "target": "inv_ncl_gate",
          "label": "Token Rail 1"
        }
      },
      {
        "data": {
          "id": "e_gate_sum1",
          "source": "inv_ncl_gate",
          "target": "dst_sum1",
          "label": "Resolved Token"
        }
      }
    ]
  },
  "style": [
    {
      "selector": "node[type='definition']",
      "style": {
        "background-color": "#2d3748",
        "label": "data(label)",
        "color": "#ffffff",
        "text-valign": "top",
        "padding": "16px",
        "border-width": 2,
        "border-color": "#4a5568"
      }
    },
    {
      "selector": "node[type='dest_place']",
      "style": {
        "background-color": "#3182ce",
        "label": "data(label)",
        "color": "#ffffff",
        "shape": "ellipse"
      }
    },
    {
      "selector": "node[type='source_place']",
      "style": {
        "background-color": "#38a169",
        "label": "data(label)",
        "color": "#ffffff",
        "shape": "ellipse"
      }
    },
    {
      "selector": "node[type='invocation']",
      "style": {
        "background-color": "#dd6b20",
        "label": "data(label)",
        "color": "#ffffff",
        "shape": "rectangle"
      }
    },
    {
      "selector": "edge",
      "style": {
        "width": 2,
        "line-color": "#cbd5e0",
        "target-arrow-color": "#cbd5e0",
        "target-arrow-shape": "triangle",
        "curve-style": "bezier",
        "label": "data(label)",
        "font-size": "10px",
        "color": "#a0aec0"
      }
    }
  ]
}
```