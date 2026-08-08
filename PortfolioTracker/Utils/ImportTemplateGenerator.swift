//
//  ImportTemplateGenerator.swift
//  PortfolioTracker
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let str = String(data: data, encoding: .utf8) {
            text = str
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ImportTemplateGenerator {
    
    static func generateTemplateCSV(for holdingType: HoldingType) -> String {
        switch holdingType {
        case .investment:
            return """
            Transaction Date,Asset Name,Transaction Type,Quantity / Units,Price per Unit,INR Exchange Rate,Notes
            2024-01-15,"Tata Consultancy Services",BUY,10,3850.50,1.0,"SIP Purchase"
            2024-03-20,"UTI Nifty 50 Index Fund",BUY,150.25,125.40,1.0,"Monthly Mutual Fund SIP"
            2024-06-10,"Tata Consultancy Services",DIVIDEND,1,480.00,1.0,"Final Dividend FY24"
            2024-07-05,"Tata Consultancy Services",SELL,5,4200.00,1.0,"Profit Booking"
            """
            
        case .epf:
            return """
            Transaction Date,Account / Organization Name,Transaction Type,Amount / Contribution,Notes
            2024-01-31,"EPFO - Main Account",EMPLOYEE_CONTRIBUTION,15000.00,"Monthly Salary Deduction"
            2024-01-31,"EPFO - Main Account",EMPLOYER_CONTRIBUTION,15000.00,"Employer Match Contribution"
            2024-02-28,"EPFO - Main Account",EMPLOYEE_CONTRIBUTION,15000.00,"Monthly Salary Deduction"
            2024-02-28,"EPFO - Main Account",EMPLOYER_CONTRIBUTION,15000.00,"Employer Match Contribution"
            2024-03-31,"EPFO - Main Account",INTEREST,24500.00,"Annual EPFO Interest Credit @ 8.25%"
            """
            
        case .fixedDeposit:
            return """
            Transaction Date,FD / Account Name,Transaction Type,Amount / Payment,Notes
            2024-01-01,"HDFC Bank 1Y FD - 908123",DEPOSIT,100000.00,"Initial FD Principal Payment"
            2024-04-01,"HDFC Bank 1Y FD - 908123",INTEREST,1850.00,"Q1 Compounded Interest Credited"
            2024-07-01,"HDFC Bank 1Y FD - 908123",INTEREST,1884.00,"Q2 Compounded Interest Credited"
            2024-12-31,"HDFC Bank 1Y FD - 908123",MATURITY,107600.00,"Full FD Maturity Payout to Savings"
            """
            
        case .insuranceAnnuity:
            return """
            Transaction Date,Policy Name / Number,Transaction Type,Amount / Premium,Notes
            2024-01-10,"LIC Jeevan Anand - Pol# 89012345",PREMIUM,50000.00,"Annual Policy Premium Receipt #4589"
            2024-03-31,"LIC Jeevan Anand - Pol# 89012345",BONUS,12500.00,"Declared Reversionary Bonus FY24"
            2024-06-15,"LIC Jeevan Anand - Pol# 89012345",SURVIVAL_BENEFIT,25000.00,"5-Year Money Back Benefit Payout"
            """
            
        case .postOffice:
            return """
            Transaction Date,Scheme Name,Transaction Type,Amount / Contribution,Notes
            2024-04-05,"Public Provident Fund (PPF)",CONTRIBUTION,150000.00,"Annual Lump Sum PPF Deposit"
            2025-03-31,"Public Provident Fund (PPF)",INTEREST,10650.00,"FY24-25 Interest Credited @ 7.1%"
            """
            
        case .bankBalance:
            return """
            Transaction Date,Bank Account Name,Transaction Type,Amount,Notes
            2024-01-01,"ICICI Savings Account",DEPOSIT,25000.00,"Opening Balance / Deposit"
            2024-03-31,"ICICI Savings Account",INTEREST,350.00,"Q4 Savings Interest Credited"
            2024-04-15,"ICICI Savings Account",WITHDRAWAL,5000.00,"ATM Cash Withdrawal"
            """
        }
    }
    
    static func generateTemplateFileURL(for holdingType: HoldingType) -> URL? {
        let safeName = holdingType.rawValue.lowercased()
        let fileName = "Import_Template_\(safeName).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let csvContent = generateTemplateCSV(for: holdingType)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write template CSV file: \(error)")
            return nil
        }
    }
}
