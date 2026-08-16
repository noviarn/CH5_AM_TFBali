//
//  CategoryItem.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//

import SwiftUI

struct CategoryItem: View {
    let category: Category
    
    var body: some View {
        NavigationLink {
            // tba — category detail / filtered list screen
        } label: {
            VStack {
                Circle()
                //                    .fill(Color.primaryPurple)
                    .frame(width: 65, height: 65)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 2, y: 2)
                    .overlay {
                        Image(category.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 65, height: 65)
                            .clipShape(Circle())
                    }
                
                Text(category.name)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.regular)
                    .foregroundStyle(.black)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        CategoryItem(category: Category(name: "Temple", image: "placeholder-default"))
        CategoryItem(category: Category(name: "Beach", image: "placeholder-default"))
    }
}
