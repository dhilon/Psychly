//
//  CalendarView.swift
//  Psychly
//
//  Created by Dhilon Prasad on 1/20/26.
//

import SwiftUI

struct CalendarView: View {
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
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
                                    DayCell(date: date, isToday: isToday(date), height: cellHeight)
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
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0

        var days: [Date?] = []

        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add days of the month
        for day in 1...numberOfDaysInMonth {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func numberOfRows() -> Int {
        let days = daysInMonth()
        return (days.count + 6) / 7
    }
}

struct DayCell: View {
    let date: Date
    let isToday: Bool
    let height: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: min(height * 0.4, 22), weight: isToday ? .bold : .medium, design: .rounded))
            .foregroundStyle(isToday ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Circle()
                    .fill(isToday ? Color.purple.opacity(0.6) : Color.clear)
                    .frame(width: min(height * 0.8, 44), height: min(height * 0.8, 44))
            )
    }
}

#Preview {
    CalendarView()
}
