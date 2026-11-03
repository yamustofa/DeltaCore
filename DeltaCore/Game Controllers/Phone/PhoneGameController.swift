//
//  PhoneGameController.swift
//  DeltaCore
//
//  Akira Arcade: a phone on the local network used as a game controller.
//
//  The phone sends one mask holding every button it is pressing, plus the position
//  of an on-screen thumb stick. PhoneGameController turns changes in those into
//  activate/deactivate calls, the same path an MFi gamepad uses, so mapping, player
//  slots and the pause menu all work without special cases.
//

import Foundation

public extension GameControllerInputType
{
    static let phone = GameControllerInputType("phone")
}

extension PhoneGameController
{
    /// Buttons on the phone, in mask bit order: bit 0 is `up`, bit 18 is `rightThumbstickRight`.
    /// The four thumb stick directions come last and are not in the mask: the phone sends
    /// the stick as axes instead (`update(leftThumbstickX:y:)`).
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
        
        case menu       // bit 14
        
        // The four directions of the right stick, which N64 maps to the C buttons.
        case rightThumbstickUp      // bit 15
        case rightThumbstickDown    // bit 16
        case rightThumbstickLeft    // bit 17
        case rightThumbstickRight   // bit 18
        
        // The thumb stick, sent as axes, not as mask bits.
        case leftThumbstickUp
        case leftThumbstickDown
        case leftThumbstickLeft
        case leftThumbstickRight
        
        /// The inputs the phone sends as bits in its mask.
        public static let buttons: [Input] = allCases.filter { !$0.isThumbstick }
        
        /// True for the analog thumb stick directions.
        public var isThumbstick: Bool {
            switch self
            {
            case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
            default: return false
            }
        }
        
        /// This button's bit in the phone's mask; 0 for the thumb stick directions.
        public var bit: UInt32 {
            guard let index = Self.buttons.firstIndex(of: self) else { return 0 }
            return 1 << UInt32(index)
        }
    }
}

extension PhoneGameController.Input: Input
{
    public var type: InputType {
        return .controller(.phone)
    }
    
    public var isContinuous: Bool {
        return self.isThumbstick
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
    public private(set) var buttonMask: UInt32 = 0
    
    /// The thumb stick position, each axis from -1 to 1 (up and right are positive).
    public private(set) var leftThumbstick: (x: Double, y: Double) = (0, 0)
    
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
    func update(buttonMask newMask: UInt32)
    {
        let changedMask = self.buttonMask ^ newMask
        guard changedMask != 0 else { return }
        
        self.buttonMask = newMask
        
        for input in Input.buttons where changedMask & input.bit != 0
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
    
    /// Applies the thumb stick position. Each axis runs from -1 to 1 (up and right are
    /// positive) and is clamped; a value inside the dead zone counts as centred.
    /// Like an MFi thumb stick, one direction per axis is active, with the tilt as its value.
    func update(leftThumbstickX x: Double, y: Double)
    {
        let x = Self.applyDeadZone(x)
        let y = Self.applyDeadZone(y)
        guard x != self.leftThumbstick.x || y != self.leftThumbstick.y else { return }
        
        self.leftThumbstick = (x, y)
        self.updateAxis(value: x, negative: .leftThumbstickLeft, positive: .leftThumbstickRight)
        self.updateAxis(value: y, negative: .leftThumbstickDown, positive: .leftThumbstickUp)
    }
    
    /// Releases every button and centres the stick, e.g. when the phone disconnects or
    /// goes quiet, so nothing stays stuck down.
    func releaseAllInputs()
    {
        self.update(buttonMask: 0)
        self.update(leftThumbstickX: 0, y: 0)
    }
}

private extension PhoneGameController
{
    /// Tilts smaller than this are treated as the stick at rest.
    static let deadZone = 0.08
    
    static func applyDeadZone(_ value: Double) -> Double
    {
        guard value.isFinite else { return 0 }
        let clamped = min(max(value, -1), 1)
        return abs(clamped) < deadZone ? 0 : clamped
    }
    
    func updateAxis(value: Double, negative: Input, positive: Input)
    {
        switch value
        {
        case ..<0:
            self.deactivate(positive)
            self.activate(negative, value: -value)
            
        case 0:
            self.deactivate(negative)
            self.deactivate(positive)
            
        default:
            self.deactivate(negative)
            self.activate(positive, value: value)
        }
    }
}
