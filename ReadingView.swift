//
//  ReadingView.swift
//  ThawabForGod
//
//  Created by Saad Sherif on 16/09/2026.
//


import SwiftUI

struct ReadingView: View {
    // Your array of text pages
    let pages: [String] = [
        "Welcome to the first page of our reading view. Swipe left to go to the next page.",
        "This is the second page. SwiftUI makes it very easy to paginate text using a TabView.",
        "Here is the third and final page. You can customize the font, padding, and background style."
    ]
    
    // Track the currently selected page index
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            // Paging TabView
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    ScrollView {
                        Text(pages[index])
                            .font(.body)
                            .lineSpacing(8)
                            .padding()
                    }
                    .tag(index) // Important: tag matches the selection state
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always)) // Makes it swipeable with page dots
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            
            // Optional: Simple page indicator text
            Text("Page \(currentPage + 1) of \(pages.count)")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
    }
}

#Preview {
    ReadingView()
}