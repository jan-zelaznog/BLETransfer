//
//  ContentView.swift
//  BLETransfer
//
//  Created by Ángel González on 20/06/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var bleManager = BLEManager()

        var body: some View {
            VStack(spacing: 20) {
                Text("BLE Transfer")
                    .font(.largeTitle)

                if let image = bleManager.receivedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .border(Color.gray)
                    Text("Imagen recibida")
                }

                Button("Enviar imagen") {
                    bleManager.startPeripheral()
                }

                Button("Recibir imagen") {
                    bleManager.startCentral()
                }
            }
            .padding()
        }
}

#Preview {
    ContentView()
}
