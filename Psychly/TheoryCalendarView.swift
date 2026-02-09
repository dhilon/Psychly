//
//  TheoryCalendarView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 2/6/26.
//

import SwiftUI

struct TheoryCalendarView: View {
    @State private var displayedMonth = Date()
    @StateObject private var theoryCalendarManager = TheoryCalendarManager()
    @StateObject private var userStatsManager = UserStatsManager()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 20) {
            // Month navigation header
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text(monthYearString(from: displayedMonth))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Days of week header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // Calendar grid
            GeometryReader { geometry in
                let rowCount = CGFloat(numberOfRows())
                let availableHeight = geometry.size.height * 0.75
                let cellHeight = availableHeight / rowCount

                VStack {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                let hasTheory = theoryCalendarManager.hasTheory(for: date)
                                let isPastWithoutTheory = !isFuture(date) && !isToday(date) && !hasTheory
                                let answer = userStatsManager.getTheoryAnswer(for: date)
                                let badgeIcon = theoryCalendarManager.getBadgeIcon(for: date)

                                if isFuture(date) {
                                    TheoryDayCell(date: date, isToday: isToday(date), isFuture: true, isPastWithoutTheory: false, height: cellHeight, badgeIcon: nil, answerState: nil)
                                } else {
                                    NavigationLink(destination: TheoryView(date: date)) {
                                        TheoryDayCell(date: date, isToday: isToday(date), isFuture: false, isPastWithoutTheory: isPastWithoutTheory, height: cellHeight, badgeIcon: badgeIcon, answerState: answer?.correct)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Color.clear
                                    .frame(height: cellHeight)
                            }
                        }
                    }
                    .frame(height: availableHeight)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Theories")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await theoryCalendarManager.loadTheoryDates()
            await userStatsManager.loadStats()
        }
        .onChange(of: displayedMonth) {
            Task {
                await theoryCalendarManager.loadTheoryDates()
            }
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDayOfMonth = calendar.date(from: components) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0

        var days: [Date?] = []

        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add days of the month
        for day in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isFuture(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let compareDate = calendar.startOfDay(for: date)
        return compareDate > today
    }

    private func numberOfRows() -> Int {
        let days = daysInMonth()
        return (days.count + 6) / 7
    }
}

struct TheoryDayCell: View {
    let date: Date
    let isToday: Bool
    let isFuture: Bool
    let isPastWithoutTheory: Bool
    let height: CGFloat
    let badgeIcon: String?
    let answerState: Bool?  // nil = not answered, true = correct, false = incorrect

    private let calendar = Calendar.current

    private var textColor: Color {
        if isToday || answerState != nil {
            return .white
        } else if isFuture || isPastWithoutTheory {
            return Color(.systemGray3)
        } else {
            return .primary
        }
    }

    private var badgeColor: Color {
        guard let correct = answerState else {
            return .clear
        }
        return correct ? .green : .red
    }

    private var backgroundColor: Color {
        if isToday {
            return Color.orange.opacity(0.6)  // Orange for theories (vs purple for experiments)
        } else if answerState != nil {
            return badgeColor.opacity(0.7)
        } else {
            return .clear
        }
    }

    var body: some View {
        ZStack {
            // Background circle (orange for today, green/red for answered)
            Circle()
                .fill(backgroundColor)
                .frame(width: min(height * 0.8, 44), height: min(height * 0.8, 44))

            // Red/green outline for answered cells
            if answerState != nil {
                Circle()
                    .stroke(badgeColor, lineWidth: 3)
                    .frame(width: min(height * 0.8, 44), height: min(height * 0.8, 44))
            }

            // Badge icon behind the number (subtle, larger)
            if let icon = badgeIcon, answerState != nil {
                Image(systemName: icon)
                    .font(.system(size: min(height * 0.5, 28)))
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Date number on top
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: min(height * 0.4, 22), weight: isToday || answerState != nil ? .bold : .medium, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

#Preview {
    NavigationStack {
        TheoryCalendarView()
    }
}
