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
    var isActive: Bool
    
    init(from app: NSRunningApplication){
        self.id = app.processIdentifier
        self.icon = app.icon
        self.name = app.localizedName
        self.isActive = app.isActive
    }
}

enum StatusApp{
    case inactive ///App no estado inicial
    case active ///Timer Ativo
    case notActive  ///Timer Parado
    
    var description: String{
        switch self {
        case .inactive:
            return "Inativo"
        case .active:
            return "Monitoramento Ativo"
        case .notActive:
            return "Monitoramento Pausado"
        }
    }
}

final class MonitorViewModel: ObservableObject{
    private let monitorService: MonitorService
    private var timerCancellable: AnyCancellable?
    private var cancellable: AnyCancellable?
        
    @Published private(set) var timerDuration: Double = 0
    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var selectApps: [AppInfo] = []
    @Published private(set) var status: StatusApp = .inactive

    init(monitorService: MonitorService = .shared){
        self.monitorService = monitorService
        self.startMonitoring()
        
        monitorService.appTerminated { [weak self] notification in
            guard let self = self else { return }
            self.selectApps.removeAll(where: {$0.id == notification.processIdentifier})
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
    
    func playTimer(){
        self.status = .active
        if timerCancellable == nil {
            self.timerCancellable = Timer
                .publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.timerDuration += 1
    //                self.verifyStatusApp()
                }
        }else{
            print("Timer ativo")
        }
        
    }
    
    func pauseTimer(){
        self.status = .notActive
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
    }
    
    func resetTimer(){
        self.timerCancellable?.cancel()
        self.timerCancellable = nil
        self.timerDuration = 0
        self.selectApps.removeAll()
    }
    
    public func getAllApps() {
        let aplications = monitorService.getAplications()
        self.apps = aplications.filter { !$0.isTerminated }.map { AppInfo(from: $0) }
    }
    
    public func verifyStatusApp(){
        let aplications = monitorService.getAplications()
        
        for app in aplications {
            for (indexSelect, selectApp) in self.selectApps.enumerated() {
                if selectApp.id == app.processIdentifier{
                    if selectApp.isActive != app.isActive{
                        self.selectApps[indexSelect].isActive = app.isActive
                    }
                }
            }
        }
        
        if !selectApps.isEmpty{
            verifyStatus()
        }
    }
    
    func verifyStatus(){
        for app in selectApps {
            print("------------------------------")
            print("\(app.name ?? "") - \(app.id)" )
            print(app.isActive)
        }
        
        if self.selectApps.contains(where: {$0.isActive}){
            playTimer()
        }else{
            pauseTimer()
        }
    }
    
    func printValues(_ app: NSRunningApplication){
        print("--------------------")
        print("\(app.localizedName ?? "") - \(app.processIdentifier) -> TERMINOU: \(app.isTerminated)")
    }
    
    public func selectApp(_ app: AppInfo){
        self.selectApps.append(app)
    }
}

struct ContentView: View {
    @StateObject private var vm: MonitorViewModel = MonitorViewModel()
    @State private var openSheet: Bool = false
    
    var body: some View {
        VStack(alignment: .center){
            Text(vm.status.description)
            
            Text("\(vm.timerDuration)")
            
            List(vm.selectApps, id: \.id) { app in
                HStack{
                    Image(nsImage: app.icon ?? NSImage())
                    
                    Text(app.name ?? "")
                    Text("\(app.id)")
                    
                    Spacer()
                    
                    if app.isActive {
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(.green)
                    }else{
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(.red)
                    }
                }
            }
            
            Button("Selecione os Apps"){
                self.openSheet.toggle()
            }
            
            HStack{
                Button("Play"){
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
 
