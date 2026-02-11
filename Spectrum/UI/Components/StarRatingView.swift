import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { number in
                Image(systemName: number <= rating ? "star.fill" : "star")
                    .font(.system(size: 24))
                    .foregroundStyle(number <= rating ? .yellow : .gray.opacity(0.5))
                    .onTapGesture {
                        withAnimation(.spring()) {
                            rating = number
                        }
                    }
            }
        }
    }
}
