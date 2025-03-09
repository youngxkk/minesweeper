//
//  ContentView.swift
//  minesweeper
//
//  Created by deepsea on 2025/2/22.
//

import SwiftUI

// MARK: - 数据模型
struct Cell: Identifiable {
    let id = UUID()
    var isMine: Bool = false
    var isRevealed: Bool = false
    var isFlagged: Bool = false
    var neighborMines: Int = 0
}

class GameBoard: ObservableObject {
    @Published var cells: [[Cell]] = []
    @Published var gameOver = false
    @Published var win = false
    @Published var remainingCells: Int = 0
    @Published var gameTime: Int = 0
    let rowCount: Int
    let columnCount: Int
    var mineCount: Int
    private var timer: Timer? = nil
    
    init(rowCount: Int = 16, columnCount: Int = 12, mineCount: Int = 32) {
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.mineCount = mineCount
        resetGame()
    }
    
    func resetGame() {
        cells = Array(repeating: Array(repeating: Cell(), count: columnCount), count: rowCount)
        var allCoordinates = (0..<rowCount).flatMap { x in (0..<columnCount).map { y in (x, y) } }
        allCoordinates.shuffle()
        
        for (x, y) in allCoordinates.prefix(mineCount) {
            cells[x][y].isMine = true
            updateNeighborMines(x: x, y: y)
        }
        
        gameOver = false
        win = false
        gameTime = 0
        updateRemainingCells()
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !self.gameOver {
                self.gameTime += 1
            }
        }
    }
    
    private func updateNeighborMines(x: Int, y: Int) {
        for i in -1...1 {
            for j in -1...1 {
                guard i != 0 || j != 0 else { continue }
                let nx = x + i, ny = y + j
                if nx >= 0 && nx < rowCount && ny >= 0 && ny < columnCount {
                    cells[nx][ny].neighborMines += 1
                }
            }
        }
    }
    
    func reveal(x: Int, y: Int) {
        guard !cells[x][y].isFlagged, !cells[x][y].isRevealed else { return }
        
        if cells[x][y].isMine {
            gameOver = true
            cells[x][y].isRevealed = true
            return
        }
        
        var stack = [(x: x, y: y)]
        while !stack.isEmpty {
            let current = stack.removeLast()
            guard !cells[current.x][current.y].isRevealed else { continue }
            cells[current.x][current.y].isRevealed = true
            
            if cells[current.x][current.y].neighborMines == 0 {
                for i in -1...1 {
                    for j in -1...1 {
                        let newX = current.x + i, newY = current.y + j
                        if newX >= 0 && newX < rowCount && newY >= 0 && newY < columnCount && !cells[newX][newY].isRevealed && !cells[newX][newY].isMine {
                            stack.append((newX, newY))
                        }
                    }
                }
            }
        }
        updateRemainingCells()
        checkWin()
    }
    
    func toggleFlagAt(x: Int, y: Int) {
        guard !cells[x][y].isRevealed else { return }
        cells[x][y].isFlagged.toggle()
    }
    
    private func checkWin() {
        if remainingCells == 0 {
            win = true
            gameOver = true
        }
    }
    
    private func updateRemainingCells() {
        remainingCells = cells.flatMap { $0 }.filter { !$0.isRevealed && !$0.isMine }.count
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject var gameBoard: GameBoard
    @State private var showWinAlert = false
    @State private var showingDifficultyOptions = false
    @State private var selectedDifficulty: String = "难度" // 默认显示"难度"
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    init() {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let rowCount = isPad ? 20 : 14
        let columnCount = isPad ? 18 : 10
        
        _gameBoard = StateObject(wrappedValue: GameBoard(rowCount: rowCount, columnCount: columnCount))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = min(geometry.size.width, geometry.size.height) * 0.9
            let cellSize = containerWidth / CGFloat(gameBoard.columnCount)
            
            VStack(spacing: isPad ? 30 : 20) {
                // 标题
                Text("复古扫雷")
                    .font(.system(size: isPad ? 34 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .shadow(color: .white, radius: 2, x: 2, y: 2)
                    .padding(.vertical, isPad ? 16 : 12)
                    .padding(.horizontal, isPad ? 40 : 30)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(white: 0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(white: 0.9), lineWidth: 4)
                                        .blur(radius: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(white: 0.4), lineWidth: 2)
                                )
                        }
                    )
                
                // 状态栏
                HStack {
                    StatusItem(title: "剩余", value: gameBoard.remainingCells)
                    
                    // 难度按钮
                    Button {
                        showingDifficultyOptions = true
                    } label: {
                        StatusItem(title: selectedDifficulty, value: nil)
                            .foregroundColor(.black) // 确保文字颜色一致
                    }
                    
                    StatusItem(title: "时长", value: gameBoard.gameTime)
                }
                .confirmationDialog("选择难度", isPresented: $showingDifficultyOptions) {
                    Button("简单") { updateDifficulty(0.1, label: "简单") }
                    Button("中等") { updateDifficulty(0.15, label: "中等") }
                    Button("困难") { updateDifficulty(0.2, label: "困难") }
                    Button("取消", role: .cancel) { }
                }
                
                // 游戏棋盘
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.75))
                        .frame(width: containerWidth + 4, height: containerWidth + 4)
                    
                    VStack(spacing: 0) {
                        ForEach(0..<gameBoard.rowCount, id: \.self) { x in
                            HStack(spacing: 0) {
                                ForEach(0..<gameBoard.columnCount, id: \.self) { y in
                                    CellView(cell: gameBoard.cells[x][y])
                                        .frame(width: cellSize, height: cellSize)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if !gameBoard.gameOver && !gameBoard.win {
                                                gameBoard.reveal(x: x, y: y)
                                            }
                                        }
                                        .onLongPressGesture {
                                            if !gameBoard.gameOver && !gameBoard.win {
                                                gameBoard.toggleFlagAt(x: x, y: y)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .border(Color(white: 0.4), width: 2)
                }
                
                // 新游戏按钮
                Button(action: {
                    gameBoard.resetGame()
                }) {
                    Text("新游戏")
                        .font(.system(size: isPad ? 24 : 18, weight: .bold, design: .rounded))
                        .padding(.vertical, isPad ? 14 : 10)
                        .padding(.horizontal, isPad ? 40 : 30)
                }
                .buttonStyle(RetroButtonStyle())
                .padding(.bottom, geometry.size.height * 0.05)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(isPad ? 30 : 20)
            .background(Color(white: 0.8).ignoresSafeArea())
            .alert(isPresented: $showWinAlert) {
                Alert(title: Text("🎉"),
                      message: Text("恭喜完成所有扫雷！") + Text("\n用时：\(gameBoard.gameTime)秒"),
                      dismissButton: .default(Text("OK")))
            }
            .onChange(of: gameBoard.win) { oldValue, newValue in
                if newValue {
                    showWinAlert = true
                }
            }
        }
    }
    
    private func updateDifficulty(_ percentage: Double, label: String) {
        let totalCells = gameBoard.rowCount * gameBoard.columnCount
        gameBoard.mineCount = max(1, Int(Double(totalCells) * percentage))
        selectedDifficulty = label // 更新显示的难度标签
        gameBoard.resetGame()
    }
    
    private struct StatusItem: View {
        let title: String
        let value: Int?
        var displayText: String {
            value != nil ? "\(title): \(value!)" : title
        }
        
        var body: some View {
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            Text(displayText)
                .font(.system(size: isPad ? 24 : 18, weight: .bold, design: .rounded))
                .foregroundColor(.black) // 统一文字颜色
                .padding(10)
                .frame(width: isPad ? 120 : 100)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white, lineWidth: 2)
                                .offset(x: -1, y: -1)
                                .blendMode(.screen)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(white: 0.4), lineWidth: 2)
                                .offset(x: 1, y: 1)
                                .blendMode(.multiply)
                        )
                )
        }
    }
}

// ...（CellView和RetroButtonStyle保持不变，与之前相同）...

// MARK: - 单元格视图
struct CellView: View {
    let cell: Cell
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(cell.isRevealed ? Color(white: 0.6) : Color(white: 0.75))
                .overlay(
                    Group {
                        if !cell.isRevealed {
                            Rectangle()
                                .inset(by: 1)
                                .stroke(Color(white: 0.8), lineWidth: 2)
                                .offset(x: -1, y: -1)
                                .blendMode(.screen)
                            
                            Rectangle()
                                .inset(by: 1)
                                .stroke(Color(white: 0.4), lineWidth: 2)
                                .offset(x: 1, y: 1)
                                .blendMode(.multiply)
                        }
                    }
                )
            
            if cell.isRevealed {
                if cell.isMine {
                    Text("💣")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                } else if cell.neighborMines > 0 {
                    Text("\(cell.neighborMines)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(numberColor)
                }
            } else if cell.isFlagged {
                Text("🚩")
                    .font(.system(size: 20))
            }
        }
    }
    
    private var numberColor: Color {
        switch cell.neighborMines {
        case 1: return .blue
        case 2: return .green
        case 3: return .red
        case 4: return .purple
        default: return .black
        }
    }
}

// MARK: - 按钮样式
struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .background(
                ZStack {
                    Color(white: 0.7)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 2)
                        .offset(x: 1, y: 1)
                        .blendMode(.screen)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.4), lineWidth: 2)
                        .offset(x: -1, y: -1)
                        .blendMode(.multiply)
                }
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
