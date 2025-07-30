//
//  ContentView.swift
//  Argos
//
//  Created by Gustavo Horestee on 29/07/25.
//

import SwiftUI
import AppKit
import Combine

final class MonitorService{
    static public let shared: MonitorService = MonitorService()
    
    private let worspace: NSWorkspace = .shared
    
    private init(){}
    
    public func getAplications() -> [NSRunningApplication]{
        return worspace.runningApplications.filter{$0.activationPolicy == .regular}
    }
    
    public func appTerminated(_ action: @escaping (NSRunningApplication) -> Void) {
        worspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main) { notification in
                if let appFechado = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    action(appFechado)
                }
            }
    }
}

struct AppInfo: Identifiable, Hashable{
    let id: pid_t
    let name: String?
    let icon: NSImage?
    let bundleIdentifier: String?
    var status: StatusApp
    
    init(from app: NSRunningApplication){
        self.id = app.processIdentifier
        self.icon = app.icon
        self.name = app.localizedName
        self.bundleIdentifier = app.bundleIdentifier
        self.status = app.isActive ? .active : .notActive
    
    }
}

enum StatusApp{
    case active ///Timer Ativo
    case notActive  ///Timer Parado
    case removedFromSystem
    
    var color: Color{
        switch self {
        case .active:
            return .green
        case .notActive:
            return .yellow
        case .removedFromSystem:
            return .red
        }
    }
}

enum StatusView{
    case inactive ///App no estado inicial
    case active ///Timer Ativo
    case notActive  ///Timer Parado
    case nothingApp
    
    var description: String{
        switch self {
        case .inactive:
            return "Inativo"
        case .active:
            return "Monitoramento Ativo"
        case .notActive:
            return "Monitoramento Pausado"
        case .nothingApp:
            return "Todos os app estão inativos/ou não estão no sistema"
        }
    }
}

final class MonitorViewModel: ObservableObject{
    private let monitorService: MonitorService
    
    private var timerCancellable: AnyCancellable?
    private var geralTimerCancellable: AnyCancellable?
    private var cancellable: AnyCancellable?
    
    @Published private(set) var timerDuration: Double = 0
    @Published private(set) var geralTimerDuration: Double = 0
    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var monitoringApps: [AppInfo] = []
    @Published private(set) var status: StatusView = .inactive
    
    init(monitorService: MonitorService = .shared){
        self.monitorService = monitorService
        
        monitorService.appTerminated { [weak self] notification in
            guard let self = self else { return }
            
            for (index, app) in self.monitoringApps.enumerated() {
                if app.bundleIdentifier == notification.bundleIdentifier {
                    self.monitoringApps[index].status = .removedFromSystem
                }
            }
        }
    }
    
    func startMonitoring(){
        self.cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.verifyStatusApp()
            }
    }
    
    func geralTime(){
        self.geralTimerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                geralTimerDuration += 1
            }
    }
    
    
    func playTimer(){
        self.status = .active

        if timerCancellable == nil {
            self.timerCancellable = Timer
                .publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.timerDuration += 1
                }
        }
    }
    
    //MARK: - Bug
    // 1 - Quando um usuario entrar em um app fora da lista de selecionados, por padrão o timer para, entretando ele não volta a contar quando o usuario volta para o app.
    
    func pauseTimer(){
        self.status = .notActive
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }
    
    func resetTimer(){
        self.status = .inactive
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
        self.timerDuration = 0
        self.geralTimerDuration = 0
        self.geralTimerCancellable?.cancel()
        self.geralTimerCancellable = nil
        self.monitoringApps.removeAll()
    }
    
    func formatTimeWithFormatter(_ totalSeconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: totalSeconds) ?? "00:00"
    }
    
    public func getAllApps() {
        let aplications = monitorService.getAplications()
        self.apps = aplications.filter { !$0.isTerminated }.map { AppInfo(from: $0) }
    }
    
    public func verifyStatusApp(){
        let aplications = monitorService.getAplications()
                
//        if self.status != .active {
//            print("Inativo")
//            return
//        }
        
        for app in aplications {
            for (indexSelect, selectApp) in self.monitoringApps.enumerated() {
                if selectApp.bundleIdentifier == app.bundleIdentifier{
                    self.monitoringApps[indexSelect].status = app.isActive ? .active : .notActive
                    
                    if selectApp.bundleIdentifier == app.bundleIdentifier && selectApp.status == .removedFromSystem{ //Foi removido mais voltou
                        self.monitoringApps[indexSelect].status = .active
                    }
                }
            }
        }
        
//        if self.status == .active { O que acontece quando nao tem validacao? ele starta antes do play
            verifyStatus()
//        }
    }
    
    func verifyStatus(){
        for app in monitoringApps {
            print("------------------------------")
            print("\(app.name ?? "") - \(app.id)" )
            print(app.status)
        }
        
        if self.monitoringApps.contains(where: { $0.status == .active }){
            playTimer()
            return
        }
        pauseTimer()
    }
    
    func printValues(_ app: NSRunningApplication){
        print("--------------------")
        print("\(app.localizedName ?? "") - \(app.processIdentifier) -> TERMINOU: \(app.isTerminated)")
    }
    
    public func selectApp(_ app: AppInfo){
        self.monitoringApps.append(app)
    }
}

struct ContentView: View {
    @StateObject private var vm: MonitorViewModel = MonitorViewModel()
    @State private var openSheet: Bool = false
    
    var body: some View {
        VStack(alignment: .center){
            Text(vm.status.description)
            
            HStack{
                VStack{
                    Text("Geral Time")
                    Text(vm.formatTimeWithFormatter(vm.geralTimerDuration))
                }
                
                Divider()
                    .frame(width: 20, height: 20)
                
                VStack{
                    Text("Product Time")
                    Text(vm.formatTimeWithFormatter(vm.timerDuration))
                }
            }
            
            List(vm.monitoringApps, id: \.id) { app in
                HStack{
                    Image(nsImage: app.icon ?? NSImage())
                    
                    Text(app.name ?? "")
                    Text("\(app.id)")
                    
                    Spacer()
                    
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(app.status.color)
                }
            }
            
            Button("Selecione os Apps"){
                self.openSheet.toggle()
            }
            
            HStack{
                Button("Play"){
                    vm.startMonitoring()
                    vm.geralTime()
                    vm.playTimer()
                }
                
                Button("Pause"){
                    vm.pauseTimer()
                }
                
                Button("Resetar"){
                    vm.resetTimer()
                }
            }
        }
        .sheet(isPresented: $openSheet){
            RunningAppsView(vm: vm)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}

struct RunningAppsView: View {
    @ObservedObject var vm: MonitorViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack{
            Text("Selecione os Apps que deseja monitorar!")
            
            List(vm.apps, id: \.id) { app in
                Button{
                    vm.selectApp(app)
                }label: {
                    HStack{
                        Image(nsImage: app.icon ?? NSImage())
                        
                        Text(app.name ?? "")
                    }
                }
            }
            
            
            Button("Pronto!"){
                dismiss()
            }
        }
        .frame(width: 200, height: 200)
        .onAppear{
            vm.getAllApps()
        }
    }
}

#Preview {
    ContentView()
}

