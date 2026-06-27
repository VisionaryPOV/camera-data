import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain

public struct DigitalSlateView: View {
    @Binding public var scene: String
    @Binding public var take: Int
    @Binding public var rollNumber: String
    @Binding public var isRolling: Bool
    @Binding public var frameRatePresetID: String
    @Binding public var manualFrameRate: Double
    @Binding public var whiteBalancePresetID: String
    @Binding public var manualWhiteBalanceKelvin: Int
    public var rollOrigin: Date?
    public var onIncrementTake: () -> Void
    public var onDismiss: () -> Void
    public var onViewAppeared: (() -> Void)?

    @State private var showManualFPS = false
    @State private var showManualWB = false

    public init(
        scene: Binding<String>,
        take: Binding<Int>,
        rollNumber: Binding<String>,
        isRolling: Binding<Bool>,
        frameRatePresetID: Binding<String>,
        manualFrameRate: Binding<Double>,
        whiteBalancePresetID: Binding<String>,
        manualWhiteBalanceKelvin: Binding<Int>,
        rollOrigin: Date?,
        onIncrementTake: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {},
        onViewAppeared: (() -> Void)? = nil
    ) {
        self._scene = scene
        self._take = take
        self._rollNumber = rollNumber
        self._isRolling = isRolling
        self._frameRatePresetID = frameRatePresetID
        self._manualFrameRate = manualFrameRate
        self._whiteBalancePresetID = whiteBalancePresetID
        self._manualWhiteBalanceKelvin = manualWhiteBalanceKelvin
        self.rollOrigin = rollOrigin
        self.onIncrementTake = onIncrementTake
        self.onDismiss = onDismiss
        self.onViewAppeared = onViewAppeared
    }

    private var resolvedFPS: Double {
        SlateSettingsResolver.resolvedFPS(presetID: frameRatePresetID, manualFPS: manualFrameRate)
    }

    private var resolvedWBLabel: String {
        SlateSettingsResolver.resolvedWhiteBalanceLabel(
            presetID: whiteBalancePresetID,
            manualKelvin: manualWhiteBalanceKelvin
        )
    }

    public var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                if isLandscape {
                    landscapeLayout(size: proxy.size)
                } else {
                    portraitLayout(size: proxy.size)
                }
            }
        }
        .onAppear {
            NSLog(
                "[CameraData] slate_view_appeared=true scene=%@ take=%d rolling=%@",
                scene,
                take,
                isRolling ? "true" : "false"
            )
            onViewAppeared?()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .accessibilityLabel("Close slate")
        }
        .sheet(isPresented: $showManualFPS) { manualFPSSheet }
        .sheet(isPresented: $showManualWB) { manualWBSheet }
    }

    private func portraitLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            clapperHeader
            timecodeDisplay(fontSize: min(size.width * 0.16, size.height * 0.12))
                .padding(.vertical, 16)
            metadataPanel
                .padding(.horizontal, 20)
            Spacer(minLength: 12)
            controls
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                clapperHeader
                metadataPanel
                Spacer()
                controls
            }
            .frame(width: size.width * 0.34)
            timecodeDisplay(fontSize: min(size.height * 0.22, size.width * 0.11))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
    }

    private var clapperHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(clapperColors.enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(color)
                    .frame(height: 18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var clapperColors: [Color] {
        [.black, .green, .yellow, .blue, .red, .white, .gray, .black]
    }

    private func timecodeDisplay(fontSize: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: SlateTimecode.timelineInterval(fps: resolvedFPS))) { context in
            let groups = SlateTimecode.digitGroups(
                from: context.date,
                origin: isRolling ? rollOrigin : nil,
                fps: resolvedFPS
            )
            VStack(spacing: 8) {
                HStack(spacing: fontSize * 0.12) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        Text(group)
                            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 1, green: 0.12, blue: 0.1))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        if index < groups.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        )
                )

                HStack {
                    ForEach(["Hours", "Minutes", "Seconds", "Frames"], id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.2))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 12)
        }
    }

    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            slateField(label: "ROLL", value: rollNumber.isEmpty ? "—" : rollNumber)
            slateField(label: "SCENE", value: scene.isEmpty ? "—" : scene, emphasized: true)
            slateField(label: "TAKE", value: "\(take)", emphasized: true)
            HStack(spacing: 16) {
                settingMenu(
                    title: "FPS",
                    selection: frameRatePresetID,
                    options: SlateFrameRateOption.presets.map { ($0.id, $0.label) },
                    onSelect: { id in
                        frameRatePresetID = id
                        if id == "manual" {
                            showManualFPS = true
                        } else if let value = SlateFrameRateOption.presets.first(where: { $0.id == id })?.value {
                            manualFrameRate = value
                        }
                    },
                    displayValue: frameRatePresetID == "manual"
                        ? String(format: "%.3f", manualFrameRate).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
                        : (SlateFrameRateOption.presets.first(where: { $0.id == frameRatePresetID })?.label ?? "\(resolvedFPS)")
                )
                settingMenu(
                    title: "WB",
                    selection: whiteBalancePresetID,
                    options: SlateWhiteBalanceOption.presets.map { ($0.id, $0.label) },
                    onSelect: { id in
                        whiteBalancePresetID = id
                        if id == "manual" {
                            showManualWB = true
                        } else if let kelvin = SlateWhiteBalanceOption.presets.first(where: { $0.id == id })?.kelvin {
                            manualWhiteBalanceKelvin = kelvin
                        }
                    },
                    displayValue: resolvedWBLabel
                )
            }
            if isRolling {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 14, height: 14)
                    Text("ROLLING")
                        .foregroundStyle(.red)
                        .font(.headline.weight(.bold))
                }
            }
        }
    }

    private func slateField(label: String, value: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ThemeTokens.accent)
            Text(value)
                .font(.system(
                    size: emphasized ? 44 : 28,
                    weight: .bold,
                    design: emphasized ? .rounded : .default
                ))
                .foregroundStyle(.white)
                .monospacedDigit()
            Divider().overlay(Color.white.opacity(0.25))
        }
    }

    private func settingMenu(
        title: String,
        selection: String,
        options: [(String, String)],
        onSelect: @escaping (String) -> Void,
        displayValue: String
    ) -> some View {
        Menu {
            ForEach(options, id: \.0) { option in
                Button(option.1) { onSelect(option.0) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ThemeTokens.accent)
                HStack {
                    Text(displayValue)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.textSecondary)
                }
                Divider().overlay(Color.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            GlassButton(isRolling ? "Stop Rolling" : "Start Rolling", isPrimary: false) {
                isRolling.toggle()
                HapticManager.light()
            }
            .frame(maxWidth: .infinity)
            GlassButton("Next Take", isPrimary: true) {
                onIncrementTake()
                HapticManager.medium()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var manualFPSSheet: some View {
        NavigationStack {
            Form {
                TextField("Frame Rate", value: $manualFrameRate, format: .number)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Manual FPS")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showManualFPS = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var manualWBSheet: some View {
        NavigationStack {
            Form {
                Stepper("Kelvin: \(manualWhiteBalanceKelvin)K", value: $manualWhiteBalanceKelvin, in: 1000...20000, step: 100)
            }
            .navigationTitle("Manual WB")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showManualWB = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}