# SFContactAlphabetListKit

Initial version: `0.0.1`

`SFContactAlphabetListKit` is a small SwiftUI helper package for rendering contact-style lists with alphabetic sectioning and a side index.

## Responsibilities

The package handles:

- Normalizing contact display names into alphabet index sections.
- Grouping identifiable items into alphabetized sections.
- Rendering a `List` with an optional draggable alphabet index.
- Supporting single selection, multi-selection, and row deletion hooks.

The host app handles:

- Providing the item collection and display-name mapping.
- Rendering each row.
- Persisting edits, selections, and deletions.

## Usage

Import the package from the host app:

```swift
import SFContactAlphabetListKit
```

Render an indexed list by passing identifiable items and row content:

```swift
AlphabetIndexedList(
    items: contacts,
    isAlphabetEnabled: true,
    displayName: { $0.displayName }
) { contact in
    Text(contact.displayName)
}
```

Use `AlphabetIndexing.sectionKey(for:)` when the app needs the same sectioning behavior outside the list view.
