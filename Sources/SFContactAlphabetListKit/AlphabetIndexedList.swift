import SwiftUI
import UIKit

public struct AlphabetSection<Item: Identifiable>: Identifiable {
    public let key: String
    public let title: String
    public let items: [Item]

    public var id: String { key }

    public init(key: String, title: String, items: [Item]) {
        self.key = key
        self.title = title
        self.items = items
    }
}

public struct AlphabetIndexedList<Item: Identifiable, RowContent: View>: View {
    private let items: [Item]
    private let isAlphabetEnabled: Bool
    private let displayName: (Item) -> String
    private let rowContent: (Item) -> RowContent
    private let selection: Binding<Item.ID?>?
    private let multiSelection: Binding<Set<Item.ID>>?
    private let onDelete: ((IndexSet, AlphabetSection<Item>) -> Void)?
    private let indexKeys: [String]
    private let indexItemHeight: CGFloat
    private let indexItemSpacing: CGFloat
    private let indexBarWidth: CGFloat

    @State private var activeSectionKey: String?
    @State private var isIndexGestureActive = false

    private let feedbackGenerator = UISelectionFeedbackGenerator()

    public init(
        items: [Item],
        isAlphabetEnabled: Bool,
        displayName: @escaping (Item) -> String,
        selection: Binding<Item.ID?>? = nil,
        multiSelection: Binding<Set<Item.ID>>? = nil,
        indexKeys: [String] = AlphabetIndexing.defaultIndexKeys,
        indexItemHeight: CGFloat = 12,
        indexItemSpacing: CGFloat = 3,
        indexBarWidth: CGFloat = 22,
        onDelete: ((IndexSet, AlphabetSection<Item>) -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.isAlphabetEnabled = isAlphabetEnabled
        self.displayName = displayName
        self.selection = selection
        self.multiSelection = multiSelection
        self.indexKeys = indexKeys
        self.indexItemHeight = indexItemHeight
        self.indexItemSpacing = indexItemSpacing
        self.indexBarWidth = indexBarWidth
        self.onDelete = onDelete
        self.rowContent = rowContent
    }

    public var body: some View {
        ScrollViewReader { proxy in
            HStack(alignment: .center, spacing: isAlphabetEnabled ? 1 : 0) {
                listContent(proxy: proxy)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if isAlphabetEnabled {
                    alphabetIndexView(proxy: proxy)
                        .frame(width: indexBarWidth)
                        .padding(.trailing, 0)
                }
            }
            .onAppear {
                syncActiveSection(with: proxy, scroll: false)
            }
            .onChange(of: itemIDs) { _, _ in
                syncActiveSection(with: proxy, scroll: false)
            }
            .onChange(of: isAlphabetEnabled) { _, _ in
                syncActiveSection(with: proxy, scroll: false)
            }
        }
    }

    private func listContent(proxy: ScrollViewProxy) -> some View {
        List(selection: activeSelectionBinding) {
            listRows
        }
        .scrollIndicators(isAlphabetEnabled ? .hidden : .visible)
    }

    @ViewBuilder
    private var listRows: some View {
        if isAlphabetEnabled {
            ForEach(groupedSections) { section in
                Section {
                    if let onDelete {
                        ForEach(section.items) { item in
                            rowContent(item)
                        }
                        .onDelete { offsets in
                            onDelete(offsets, section)
                        }
                    } else {
                        ForEach(section.items) { item in
                            rowContent(item)
                        }
                    }
                } header: {
                    Text(section.title)
                        .id(section.key)
                }
            }
        } else {
            ForEach(items) { item in
                rowContent(item)
            }
        }
    }

    @ViewBuilder
    private func alphabetIndexView(proxy: ScrollViewProxy) -> some View {
        let availableKeys = Set(groupedSections.map(\.key))

        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: indexItemSpacing) {
                    ForEach(indexKeys, id: \.self) { key in
                        let isAvailable = availableKeys.contains(key)
                        let isActive = activeSectionKey == key
                        Text(key)
                            .font(.caption2.weight(isActive ? .bold : .medium))
                            .foregroundStyle(isAvailable ? Color.blue : Color.secondary.opacity(0.45))
                            .frame(width: 18, height: indexItemHeight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isIndexGestureActive {
                            isIndexGestureActive = true
                            feedbackGenerator.prepare()
                        }
                        handleIndexGesture(
                            value.location,
                            in: geometry.size.height,
                            availableKeys: availableKeys,
                            proxy: proxy
                        )
                    }
                    .onEnded { _ in
                        isIndexGestureActive = false
                    }
            )
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 2)
        .padding(.horizontal, 0)
    }

    private func syncActiveSection(with proxy: ScrollViewProxy, scroll: Bool) {
        guard isAlphabetEnabled else {
            activeSectionKey = nil
            return
        }
        guard let firstSectionKey = groupedSections.first?.key else {
            activeSectionKey = nil
            return
        }
        if activeSectionKey == nil || !hasSection(activeSectionKey ?? "") {
            activeSectionKey = firstSectionKey
            if scroll {
                proxy.scrollTo(firstSectionKey, anchor: .top)
            }
        }
    }

    private func handleIndexGesture(
        _ location: CGPoint,
        in containerHeight: CGFloat,
        availableKeys: Set<String>,
        proxy: ScrollViewProxy
    ) {
        guard !indexKeys.isEmpty, containerHeight > 0 else { return }

        let contentHeight = CGFloat(indexKeys.count) * indexItemHeight
            + CGFloat(max(indexKeys.count - 1, 0)) * indexItemSpacing
        let topBlankHeight = max((containerHeight - contentHeight) / 2, 0)
        let bottomBlankStart = topBlankHeight + contentHeight

        let clampedIndex: Int
        if location.y <= topBlankHeight {
            clampedIndex = firstAvailableIndex(in: availableKeys) ?? 0
        } else if location.y >= bottomBlankStart {
            clampedIndex = lastAvailableIndex(in: availableKeys) ?? (indexKeys.count - 1)
        } else {
            let relativeY = location.y - topBlankHeight
            let step = indexItemHeight + indexItemSpacing
            let mappedIndex = Int(floor(relativeY / step))
            clampedIndex = min(max(mappedIndex, 0), indexKeys.count - 1)
        }

        let key = indexKeys[clampedIndex]
        guard availableKeys.contains(key) else { return }
        scrollToSection(key, using: proxy, feedback: true)
    }

    private func scrollToSection(_ key: String, using proxy: ScrollViewProxy, feedback: Bool) {
        guard hasSection(key) else { return }
        if activeSectionKey != key {
            activeSectionKey = key
            if feedback {
                feedbackGenerator.selectionChanged()
                feedbackGenerator.prepare()
            }
        }
        proxy.scrollTo(key, anchor: .top)
    }

    private func hasSection(_ key: String) -> Bool {
        groupedSections.contains(where: { $0.key == key })
    }

    private func firstAvailableIndex(in availableKeys: Set<String>) -> Int? {
        indexKeys.firstIndex(where: { availableKeys.contains($0) })
    }

    private func lastAvailableIndex(in availableKeys: Set<String>) -> Int? {
        indexKeys.lastIndex(where: { availableKeys.contains($0) })
    }

    private var groupedSections: [AlphabetSection<Item>] {
        guard isAlphabetEnabled else { return [] }

        var grouped: [String: [Item]] = [:]
        for item in items {
            let key = AlphabetIndexing.sectionKey(for: displayName(item))
            grouped[key, default: []].append(item)
        }

        let existing = Set(grouped.keys)
        let ordered = indexKeys.filter { existing.contains($0) }
        return ordered.map { key in
            AlphabetSection(key: key, title: key, items: grouped[key] ?? [])
        }
    }

    private var itemIDs: [Item.ID] {
        items.map(\.id)
    }

    private var activeSelectionBinding: Binding<Set<Item.ID>>? {
        if let multiSelection {
            return multiSelection
        }
        guard let selection else {
            return nil
        }
        return Binding<Set<Item.ID>>(
            get: {
                guard let selectedID = selection.wrappedValue else { return [] }
                return [selectedID]
            },
            set: { newValue in
                selection.wrappedValue = newValue.first
            }
        )
    }
}
