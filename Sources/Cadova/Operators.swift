import Foundation

precedencegroup CrossProductPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
    lowerThan: MultiplicationPrecedence
}

infix operator × : CrossProductPrecedence
infix operator ⋅ : MultiplicationPrecedence
infix operator ×= : AssignmentPrecedence

postfix operator °
