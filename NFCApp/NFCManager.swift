//
//  NFCReader.swift
//  NFCReader
//
//  Created by Javier Calatrava on 23/12/24.
//

import Foundation
import CoreNFC


protocol NFCManagerProtocol {
    @MainActor var tagMessage: String { get }
    func startReading() async
    func startWriting(message: String) async
    func startWritingURL() async
}

final class NFCManager: NSObject, ObservableObject,
                        @unchecked Sendable  {
    
    @MainActor
    static let shared = NFCManager()
    @MainActor
    @Published var tagMessage = ""
    
    private var internalTagMessage: String = "" {
        @Sendable didSet {
            Task { [internalTagMessage] in
                await MainActor.run {
                    self.tagMessage = internalTagMessage
                }
            }
        }
    }
    
    enum NFCOperation {
        case read
        case write
        case writeURL
        case writeDeeplink
    }
    
    enum NFCError: Error {
        case badFormedURL
    }

    
    var nfcSession: NFCNDEFReaderSession?
    var nfcOperation = NFCOperation.read
    private var userMessage: String?
    
    
    @MainActor override init() {
    }
}

// MARK :- NFCManagerProtocol
extension NFCManager: NFCManagerProtocol {
    
    func startReading() async {
        nfcOperation = .read
        startSesstion()
    }
    
    func startWriting(message: String) async {
        nfcOperation = .write
        userMessage = message
        startSesstion()
    }
    
    func startWritingURL() async {
        nfcOperation = .writeURL
        startSesstion()
    }
    
    func startWritingDeeplink() async {
        nfcOperation = .writeDeeplink
        startSesstion()
    }
    
    private func startSesstion() {
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.begin()
    }
}

// MARK :- NFCNDEFReaderSessionDelegate
extension NFCManager:  NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {

    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Error checking NDEF status")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Not compatible tat")
                case  .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    switch self.nfcOperation {
                    case .read:
                        self.read(session: session, tag: tag)
                    case .write:
                        self.write(session: session, tag: tag)
                    case .writeURL:
                        self.writeUrl(session: session, tag: tag, urlString: "https://javios.eu/portfolio/")
                    case .writeDeeplink:
                        self.writeUrl(session: session, tag: tag, urlString: "nfcreader://jca.nfcreader.open")
                    }
                    
                @unknown default:
                    session.invalidate(errorMessage: "Unknown NDEF status")
                }
            }
        }
    }
    
    private func read(session: NFCNDEFReaderSession, tag: NFCNDEFTag) {
        tag.readNDEF { [weak self] message, error in
            if let error {
                session.invalidate(errorMessage: "Reading error: \(error.localizedDescription)")
                return
            }
            
            guard let message else {
                session.invalidate(errorMessage: "No recrods found")
                return
            }
            
            if let record = message.records.first {
                let tagMessage = String(data: record.payload, encoding: .utf8) ?? ""
                print(">>> Read: \(tagMessage)")
                session.alertMessage = "ReadingSucceeded: \(tagMessage)"
                session.invalidate()
                self?.internalTagMessage = tagMessage
            }
        }
    }
    
    private func write(session: NFCNDEFReaderSession, tag: NFCNDEFTag) {
        guard let userMessage  = self.userMessage else { return }
        let payload = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: userMessage.data(using: .utf8)!
        )
        write(session, tag, payload) { error in
            guard  error == nil else { return }
            print(">>> Write: \(userMessage)")
        }
    }
    
    private func writeUrl(session: NFCNDEFReaderSession, tag: NFCNDEFTag, urlString: String) {
        guard let url = URL(string: urlString),
            let payload = NFCNDEFPayload.wellKnownTypeURIPayload(string: url.absoluteString) else {
            session.invalidate(errorMessage: "No se pudo crear el payload NDEF.")
            return
        }

        write(session, tag, payload) { error in
            guard  error == nil else { return }
            print(">>> Write: \(url.absoluteString)")
        }
    }
    
    private func write(_ session: NFCNDEFReaderSession,
                       _ tag: NFCNDEFTag,
                       _ nfcNdefPayload: NFCNDEFPayload, completion: @escaping ((Error?) -> Void)) {
        
        let NDEFMessage = NFCNDEFMessage(records: [nfcNdefPayload])
        tag.writeNDEF(NDEFMessage) { error in
            if let error = error {
                session.invalidate(errorMessage: "Writing error: \(error.localizedDescription)")
                completion(error)
            } else {
                session.alertMessage = "Writing succeeded"
                session.invalidate()
                completion(nil)
            }
        }
    }
    
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print( "Error de sesión: \(error.localizedDescription)")
    }
}

