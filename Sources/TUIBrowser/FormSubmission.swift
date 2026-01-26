// TUIBrowser - Form Submission
//
// Handles HTML form data collection and URL building for form submission.

import Foundation
import TUIHTMLParser
import TUIURL

/// Handles form data collection and submission
public struct FormSubmission {

    public init() {}

    // MARK: - Form Data Collection

    /// Collect all form data from a form element
    /// - Parameter form: The form element
    /// - Returns: Array of name-value pairs
    public func collectFormData(_ form: Element) -> [(name: String, value: String)] {
        var data: [(String, String)] = []

        func traverse(_ element: Element) {
            let tagName = element.tagName.lowercased()

            switch tagName {
            case "input":
                if let name = element.getAttribute("name"), !name.isEmpty {
                    let inputType = element.getAttribute("type")?.lowercased() ?? "text"

                    switch inputType {
                    case "checkbox", "radio":
                        // Only include if checked
                        if element.hasAttribute("checked") {
                            let value = element.getAttribute("value") ?? "on"
                            data.append((name, value))
                        }
                    case "submit", "button", "image", "reset":
                        // Don't include submit buttons in form data
                        break
                    case "file":
                        // File inputs not supported
                        break
                    default:
                        // Text, password, email, etc.
                        let value = element.getAttribute("value") ?? ""
                        data.append((name, value))
                    }
                }

            case "select":
                if let name = element.getAttribute("name"), !name.isEmpty {
                    // Find selected option
                    var selectedValue: String? = nil
                    for child in element.children {
                        if child.tagName.lowercased() == "option" {
                            if child.hasAttribute("selected") {
                                selectedValue = child.getAttribute("value") ?? child.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                                break
                            }
                        }
                    }
                    // If no option is selected, use the first one
                    if selectedValue == nil, let firstOption = element.children.first(where: { $0.tagName.lowercased() == "option" }) {
                        selectedValue = firstOption.getAttribute("value") ?? firstOption.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let value = selectedValue {
                        data.append((name, value))
                    }
                }

            case "textarea":
                if let name = element.getAttribute("name"), !name.isEmpty {
                    let value = element.textContent
                    data.append((name, value))
                }

            default:
                break
            }

            // Traverse children
            for child in element.children {
                traverse(child)
            }
        }

        traverse(form)
        return data
    }

    // MARK: - URL Building

    /// Build the submit URL for a form
    /// - Parameters:
    ///   - form: The form element
    ///   - baseURL: The current page URL
    /// - Returns: The complete URL for form submission
    public func buildSubmitURL(_ form: Element, baseURL: TUIURL.URL) -> String? {
        let action = form.getAttribute("action") ?? ""
        let method = form.getAttribute("method")?.uppercased() ?? "GET"
        let data = collectFormData(form)

        // Resolve action URL
        let actionURL: String
        if action.isEmpty {
            // Submit to current URL
            actionURL = baseURL.description
        } else if action.hasPrefix("http://") || action.hasPrefix("https://") {
            actionURL = action
        } else if action.hasPrefix("//") {
            actionURL = "\(baseURL.scheme):\(action)"
        } else if action.hasPrefix("/") {
            var port = ""
            if let p = baseURL.port {
                port = ":\(p)"
            }
            actionURL = "\(baseURL.scheme)://\(baseURL.host ?? "")\(port)\(action)"
        } else {
            // Relative URL
            var basePath = baseURL.path
            if !basePath.hasSuffix("/") {
                basePath = (basePath as NSString).deletingLastPathComponent
            }
            if basePath.isEmpty {
                basePath = "/"
            }
            var port = ""
            if let p = baseURL.port {
                port = ":\(p)"
            }
            let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(action)" : "\(basePath)/\(action)"
            actionURL = "\(baseURL.scheme)://\(baseURL.host ?? "")\(port)\(fullPath)"
        }

        // For GET requests, append query string
        if method == "GET" && !data.isEmpty {
            let queryString = data.map { name, value in
                let encodedName = urlEncode(name)
                let encodedValue = urlEncode(value)
                return "\(encodedName)=\(encodedValue)"
            }.joined(separator: "&")

            if actionURL.contains("?") {
                return "\(actionURL)&\(queryString)"
            } else {
                return "\(actionURL)?\(queryString)"
            }
        }

        // For POST requests, just return the action URL
        // (actual POST body handling would require more work)
        return actionURL
    }

    // MARK: - URL Encoding

    /// URL encode a string
    private func urlEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}
