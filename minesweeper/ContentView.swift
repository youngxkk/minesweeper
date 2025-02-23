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
    @Published var gameTime: Int = 0 // 游戏时长（秒）
    let rowCount: Int
    let columnCount: Int
    let mineCount: Int
    private var timer: Timer? = nil
    //在这里调节游戏的难度，修改mineCount的数值即可
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
        
        // 重置地雷
        for (x, y) in allCoordinates.prefix(mineCount) {
            cells[x][y].isMine = true
            updateNeighborMines(x: x, y: y)
        }
        
        gameOver = false
        win = false
        gameTime = 0 // 重置游戏时长
        updateRemainingCells()
        
        // 启动计时器
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate() // 如果已有定时器，先停止
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
            gameOver = true // 游戏结束
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
    
    init() {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let rowCount = isPad ? 20 : 14  // iPad 使用 24 行，iPhone 使用 14 行
        let columnCount = isPad ? 18 : 10  // iPad 使用186 列，iPhone 使用 10 列
        
        _gameBoard = StateObject(wrappedValue: GameBoard(rowCount: rowCount, columnCount: columnCount))
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 自适应布局核心计算
            let containerWidth = min(geometry.size.width, geometry.size.height) * 0.9
            let cellSize = containerWidth / CGFloat(gameBoard.columnCount)
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            
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
                
                HStack {
                    // 剩余地雷显示
                    Text("剩余: \(gameBoard.remainingCells)")
                        .font(.system(size: isPad ? 24 : 18, weight: .bold, design: .rounded))
                        .padding(10)
                        .frame(width: isPad ? 180 : 150)
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
                    
                    // 游戏时长显示
                    Text("时长: \(gameBoard.gameTime)秒")
                        .font(.system(size: isPad ? 24 : 18, weight: .bold, design: .rounded))
                        .padding(10)
                        .frame(width: isPad ? 180 : 150)
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
                
//                Spacer() // 将按钮推到顶部和底部之间的空间
                
                // 控制按钮
                Button(action: {
                    gameBoard.resetGame()
                }) {
                    Text("新游戏")
                        .font(.system(size: isPad ? 24 : 18, weight: .bold, design: .rounded))
                        .padding(.vertical, isPad ? 14 : 10)
                        .padding(.horizontal, isPad ? 40 : 30)
                }
                .buttonStyle(RetroButtonStyle())
                .padding(.bottom, geometry.size.height * 0.05) // 设置按钮距离底部的距离为屏幕高度的 5%
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
}


// MARK: - 单元格视图
struct CellView: View {
    let cell: Cell
    
    var body: some View {
        ZStack {
            // 单元格背景
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
            
            // 显示内容
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
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.4), lineWidth: 2)
                        .offset(x: -1, y: -1)
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
