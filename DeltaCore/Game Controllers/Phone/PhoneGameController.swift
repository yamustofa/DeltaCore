//
//  PhoneGameController.swift
//  DeltaCore
//
//  Akira Arcade: a phone on the local network used as a game controller.
//
//  The phone sends one 16-bit mask holding every button it is pressing.
//  PhoneGameController turns changes in that mask into activate/deactivate calls,
//  the same path an MFi gamepad uses, so mapping, player slots and the pause menu
//  all work without special cases.
//

import Foundation

public extension GameControllerInputType
{
    static let phone = GameControllerInputType("phone")
}

extension PhoneGameController
{
    /// Buttons on the phone, in mask bit order: bit 0 is `up`, bit 14 is `menu`.
    /// Raw values match `StandardGameControllerInput`, so the default mapping is one to one.
    public enum Input: String, Codable, CaseIterable
    {
        case up         // bit 0
        case down       // bit 1
        case left       // bit 2
        case right      // bit 3
        
        case a          // bit 4
        case b          // bit 5
        case x          // bit 6
        case y          // bit 7
        
        case l1         // bit 8
        case r1         // bit 9
        
        case start      // bit 10
        case select     // bit 11
        
        case l2         // bit 12
        case r2         // bit 13
        
        case menu       // bit 14 (bit 15 is reserved)
        
        /// This button's bit in the phone's mask.
        public var bit: UInt16 {
            let index = Self.allCases.firstIndex(of: self)!
            return 1 << UInt16(index)
        }
    }
}

extension PhoneGameController.Input: Input
{
    public var type: InputType {
        return .controller(.phone)
    }
    
    public var isContinuous: Bool {
        return false
    }
}

public class PhoneGameController: NSObject, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public let name: String
    
    public var playerIndex: Int?
    
    public let inputType: GameControllerInputType = .phone
    
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingProtocol? = {
        var inputMapping = GameControllerInputMapping(gameControllerInputType: .phone)
        
        for input in Input.allCases
        {
            guard let standardInput = StandardGameControllerInput(rawValue: input.rawValue) else { continue }
            inputMapping.set(standardInput, forControllerInput: input)
        }
        
        return inputMapping
    }()
    
    /// The buttons currently held, as last reported by the phone.
    public private(set) var buttonMask: UInt16 = 0
    
    //MARK: - Initializers -
    /** Initializers **/
    public init(name: String = NSLocalizedString("Phone Controller", comment: ""))
    {
        self.name = name
        
        super.init()
    }
}

//MARK: - Input -
/** Input **/
public extension PhoneGameController
{
    /// Applies the phone's latest button mask: newly pressed buttons are activated and
    /// released ones deactivated. Sending the same mask again changes nothing.
    /// Call on the main thread, like the other game controllers' input handlers.
    func update(buttonMask newMask: UInt16)
    {
        let changedMask = self.buttonMask ^ newMask
        guard changedMask != 0 else { return }
        
        self.buttonMask = newMask
        
        for input in Input.allCases where changedMask & input.bit != 0
        {
            if newMask & input.bit != 0
            {
                self.activate(input)
            }
            else
            {
                self.deactivate(input)
            }
        }
    }
    
    /// Releases every button, e.g. when the phone disconnects or goes quiet,
    /// so no button stays stuck down.
    func releaseAllInputs()
    {
        self.update(buttonMask: 0)
    }
}
