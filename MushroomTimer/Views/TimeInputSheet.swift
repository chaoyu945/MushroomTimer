import SwiftUI

/// 輸入介面的狀態與規則。抽出來是為了能單獨測試。
@Observable
final class TimeInputModel {
    private(set) var digits = ""
    var leadSeconds: Int

    init(leadSeconds: Int) {
        self.leadSeconds = SettingsStore.leadRange.clamping(leadSeconds)
    }

    var remainingSeconds: Int? {
        DurationInput.seconds(fromDigits: digits)
    }

    func append(_ digit: String) {
        guard digits.count < DurationInput.maxDigits else { return }
        digits += digit
    }

    func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    /// 「剛爆」：剩餘時間歸零。
    func justPopped() {
        digits = ""
    }

    func adjustLead(by delta: Int) {
        leadSeconds = SettingsStore.leadRange.clamping(leadSeconds + delta)
    }

    /// 即時預覽,例如「7:15 後提醒 · 21:43:20」。
    func preview(now: Date = .now, respawnSeconds: Int) -> String {
        guard let remainingSeconds else { return "輸入不正確" }
        guard let fireAt = TimerCalculator.fireAt(
            now: now,
            remainingSeconds: remainingSeconds,
            respawnSeconds: respawnSeconds,
            leadSeconds: leadSeconds
        ) else { return "時間已過" }

        // 直接用整數算，不要繞過 TimeInterval——這個值本來就是整數秒。
        let offset = remainingSeconds + respawnSeconds - leadSeconds
        return "\(DurationInput.formatted(seconds: offset)) 後提醒 · \(DurationInput.clockTime(fireAt))"
    }

    /// 能不能建立。與 `preview` 走同一條判斷，避免畫面顯示「時間已過」卻還按得下去。
    func canConfirm(now: Date = .now, respawnSeconds: Int) -> Bool {
        guard let remainingSeconds else { return false }
        return TimerCalculator.fireAt(
            now: now,
            remainingSeconds: remainingSeconds,
            respawnSeconds: respawnSeconds,
            leadSeconds: leadSeconds
        ) != nil
    }
}

/// 剩餘時間輸入。所有按鈕都在畫面下半部,方便單手操作。
struct TimeInputSheet: View {
    let mushroomName: String
    let groupName: String
    let respawnSeconds: Int
    /// 參數依序是 remainingSeconds、leadSeconds。
    let onConfirm: (Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: TimeInputModel

    init(
        mushroomName: String,
        groupName: String,
        leadSeconds: Int,
        respawnSeconds: Int,
        onConfirm: @escaping (Int, Int) -> Void
    ) {
        self.mushroomName = mushroomName
        self.groupName = groupName
        self.respawnSeconds = respawnSeconds
        self.onConfirm = onConfirm
        _model = State(initialValue: TimeInputModel(leadSeconds: leadSeconds))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(mushroomName).font(.title2.bold())
                Text(groupName).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            Text(bigReadout)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(model.remainingSeconds == nil ? .red : .primary)

            Text(model.preview(respawnSeconds: respawnSeconds))
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("−5s") { model.adjustLead(by: -5) }
                Text("提前 \(model.leadSeconds) 秒")
                    .font(.subheadline)
                    .frame(minWidth: 90)
                Button("+5s") { model.adjustLead(by: 5) }
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            keypad

            Button {
                guard let remaining = model.remainingSeconds else { return }
                onConfirm(remaining, model.leadSeconds)
                dismiss()
            } label: {
                Text("建立提醒")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canConfirm(respawnSeconds: respawnSeconds))
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    /// 大字readout。解析不出來時直接把使用者按的數字原樣顯示，
    /// 不要退回 "0:00"——那會被誤讀成合法的「剛爆」。
    private var bigReadout: String {
        if model.digits.isEmpty { return "剛爆" }
        guard let seconds = model.remainingSeconds else { return model.digits }
        return DurationInput.formatted(seconds: seconds)
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(digit) { model.append(digit) }
                    }
                }
            }
            HStack(spacing: 10) {
                keyButton("剛爆") { model.justPopped() }
                keyButton("0") { model.append("0") }
                keyButton("⌫") { model.deleteLast() }
            }
        }
        .padding(.horizontal)
    }

    private func keyButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
    }
}
