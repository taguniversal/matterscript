# Appendix A: Language Reference

## 1. Top-Level Structure & Definitions

### Definition Declarations

Definitions are declared using a name followed immediately by square brackets `[...]`. The brackets enclose the definition's body, including its sources, destinations, field of resolution, domain specifier, and transform rules.

* **Syntax:** `NAME[(sources)(destinations) domain_specifier : body]`
* **Identifier Identifier:** Any standard alphanumeric identifier preceding `[` is classified as a definition name (`entity.name.type.definition`).

### Domain Specifier

The resolution/domain specifier section defines the operational domain or spatial context of the definition.

* **Domain Keywords:** Currently, the set includes:
* `spatial3d`



---

## 2. Invocations & Place References

### Invocations

Invocations execute/instantiate named relationships or functions.

* **Syntax:** `NAME($dest1 $dest2)(source1<> source2<>)`
* **Identifier:** Any identifier preceding `(` is classified as an invocation (`entity.name.function.invocation`).

### Destination Places

Destination places or dynamic name compositions are prefixed with a dollar sign `$`.

* **Syntax:** `$identifier`
* **Token Classification:** `variable.parameter.destination`
* **Pattern:** `\$[A-Za-z_][A-Za-z0-9_]*`

### Source Places

Source places represent incoming causal signals or inputs and are denoted by trailing angle brackets that enclose the content or reference to connect to that signal `<>`.

* **Syntax:** `name<>` or `name<content>`
* **Token Classification:** `entity.name.function.place`
* **Pattern:** `NAME(?=\s*<)`

---

## 3. Control Keywords & Built-in Functions

### Procedural / Code Generation Keywords

* **`generate`**: Declares code-generation blocks (`keyword.control`).

### Structure Field Labels

Key-value declarations preceding a colon `:`:

* `inputs:`
* `output:`
* `const:`

### Built-in Support Functions

Functions expecting argument lists in parentheses:

* `clamp(...)`
* `avg(...)`

---

## 4. Lexical Tokens & Punctuation

### Comments

* **Line Comment:** Double slashes `//` ignore all remaining text on the line.

### Literals & Arithmetic

* **Numeric Constants:** Unsigned integer literals (`\b[0-9]+\b`).
* **Arithmetic Operators:** Standard mathematical operations: `+`, `-`, `*`, `/`.

### Structural Delimiters & Delimiting Groups

| Delimiter | Token Name | Structural Purpose |
| --- | --- | --- |
| `{` `}` | `punctuation.definition.group.mutex` | Encloses mutex or conditional completeness groups. |
| `[` `]` | `punctuation.definition.bracket` | Encloses bundle brackets or definition outer bodies. |
| `(` `)` | `punctuation.definition.paren` | Encloses parameter lists and source/destination bindings. |
| `<` `>` | `punctuation.definition.place` | Enclose source place boundaries. |
| `:` | `punctuation.separator.colon` | Separates domain specifiers from bodies, or key-value entries. |
| `,` | `punctuation.separator.comma` | Separates itemized arguments or entries. |

*Drafting in progress...*

