import Foundation
import SwiftUI

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String = "English" {
        didSet {
            updateLanguage()
            // Save to UserDefaults
            UserDefaults.standard.set(currentLanguage, forKey: "user_language")
        }
    }
    
    private init() {
        // Load saved language from UserDefaults
        if let savedLanguage = UserDefaults.standard.string(forKey: "user_language") {
            currentLanguage = savedLanguage
        } else {
            // Default to English if no saved language
            currentLanguage = "English"
            UserDefaults.standard.set("English", forKey: "user_language")
        }
        updateLanguage()
    }
    
    private func updateLanguage() {
        // This will be called when language changes
        // The actual language application happens in the LocalizedString struct
    }
}

// MARK: - Localized Strings
struct LocalizedString {
    static func localized(_ key: String) -> String {
        switch LocalizationManager.shared.currentLanguage {
        case "Spanish":
            return spanishStrings[key] ?? key
        case "French":
            return frenchStrings[key] ?? key
        case "German":
            return germanStrings[key] ?? key
        case "Chinese":
            return chineseStrings[key] ?? key
        default: // English
            return englishStrings[key] ?? key
        }
    }
    
    // English strings
    private static let englishStrings: [String: String] = [
        // Profile & Settings
        "profile_settings": "Profile & Settings",
        "personal_information": "Personal Information",
        "display_name": "Display Name",
        "bio": "Bio",
        "location": "Location",
        "edit": "Edit",
        "not_set": "Not set",
        "tap_to_upload_photo": "Tap to upload photo",
        "wallet_information": "Wallet Information",
        "tls_address": "TLS Address",
        "tap_to_copy": "Tap to copy",
        "subscription": "Subscription",
        "active": "Active",
        "inactive": "Inactive",
        "ai_status": "AI Status",
        "xai_grok_integration": "xAI Grok Integration",
        "ai_features_configured": "AI features are automatically configured",
        "security_sessions": "Security & Sessions",
        "biometric_authentication": "Biometric Authentication",
        "manage_sessions": "Manage Sessions",
        "preferences": "Preferences",
        "language": "Language",
        "currency": "Currency",
        "theme": "Theme",
        "analytics": "Analytics",
        "view_usage_analytics": "View Usage Analytics",
        "support_help": "Support & Help",
        "report_bug": "Report a Bug",
        "speak_with_team": "Speak with Team",
        "save_changes": "Save Changes",
        "unsaved_changes": "Unsaved Changes",
        "unsaved_changes_message": "You have unsaved changes. Would you like to save before leaving?",
        "save": "Save",
        "discard": "Discard",
        "cancel": "Cancel",
        
        // Edit Personal Info
        "edit_info": "Edit Info",
        "display_name_placeholder": "Display Name",
        "bio_placeholder": "Bio",
        "location_placeholder": "Location",
        
        // Common
        "back": "Back",
        "ok": "OK",
        "error": "Error",
        "success": "Success",
        "loading": "Loading...",
        "coming_soon": "Coming Soon",
        
        // Home
        "home": "Home",
        "messages": "Messages",
        "profile": "Profile",
        "your_ai_assistant": "Your AI Assistant",
        "sign_in": "Sign In",
        "create_new_account": "Create New Account",
        "enter_wallet_address": "Enter Wallet Address",
        "enter_mnemonic": "Enter Mnemonic",
        "both_required": "Both address and mnemonic are required",
        "invalid_credentials": "Invalid address or mnemonic",
        "address_copied": "Address copied to clipboard!",
        
        // Messages
        "new_chat": "New Chat",
        "contact_information": "Contact Information",
        "contact_name": "Contact Name",
        "tls_address_field": "TLS Address",
        "create": "Create",
        "new_conversation_created": "New conversation created!",
        "participants": "participants",
        "no_messages_yet": "No messages yet",
        "type_message": "Type a message...",
        
        // Analytics
        "usage_statistics": "Usage Statistics",
        "daily_active_minutes": "Daily Active Minutes",
        "average_transaction_size": "Average Transaction Size",
        "total_transactions": "Total Transactions",
        "total_volume": "Total Volume",
        
        // Bug Report
        "report_bug_title": "Report Bug",
        "bug_details": "Bug Details",
        "category": "Category",
        "describe_bug": "Describe the bug...",
        "submit": "Submit",
        "bug_submitted": "Bug report submitted successfully!"
    ]
    
    // Spanish strings
    private static let spanishStrings: [String: String] = [
        "profile_settings": "Perfil y Configuración",
        "personal_information": "Información Personal",
        "display_name": "Nombre de Pantalla",
        "bio": "Biografía",
        "location": "Ubicación",
        "edit": "Editar",
        "not_set": "No establecido",
        "tap_to_upload_photo": "Toca para subir foto",
        "wallet_information": "Información de Billetera",
        "tls_address": "Dirección TLS",
        "tap_to_copy": "Toca para copiar",
        "subscription": "Suscripción",
        "active": "Activa",
        "inactive": "Inactiva",
        "ai_status": "Estado de IA",
        "xai_grok_integration": "Integración xAI Grok",
        "ai_features_configured": "Las funciones de IA se configuran automáticamente",
        "security_sessions": "Seguridad y Sesiones",
        "biometric_authentication": "Autenticación Biométrica",
        "manage_sessions": "Gestionar Sesiones",
        "preferences": "Preferencias",
        "language": "Idioma",
        "currency": "Moneda",
        "theme": "Tema",
        "analytics": "Analíticas",
        "view_usage_analytics": "Ver Analíticas de Uso",
        "support_help": "Soporte y Ayuda",
        "report_bug": "Reportar Error",
        "speak_with_team": "Hablar con el Equipo",
        "save_changes": "Guardar Cambios",
        "unsaved_changes": "Cambios Sin Guardar",
        "unsaved_changes_message": "Tienes cambios sin guardar. ¿Te gustaría guardar antes de salir?",
        "save": "Guardar",
        "discard": "Descartar",
        "cancel": "Cancelar",
        "edit_info": "Editar Información",
        "display_name_placeholder": "Nombre de Pantalla",
        "bio_placeholder": "Biografía",
        "location_placeholder": "Ubicación",
        "back": "Atrás",
        "ok": "OK",
        "error": "Error",
        "success": "Éxito",
        "loading": "Cargando...",
        "coming_soon": "Próximamente",
        "home": "Inicio",
        "messages": "Mensajes",
        "profile": "Perfil",
        "your_ai_assistant": "Tu Asistente de IA",
        "sign_in": "Iniciar Sesión",
        "create_new_account": "Crear Nueva Cuenta",
        "enter_wallet_address": "Ingresa Dirección de Billetera",
        "enter_mnemonic": "Ingresa Mnemónico",
        "both_required": "Se requieren tanto la dirección como el mnemónico",
        "invalid_credentials": "Dirección o mnemónico inválidos",
        "address_copied": "¡Dirección copiada al portapapeles!",
        "new_chat": "Nuevo Chat",
        "contact_information": "Información de Contacto",
        "contact_name": "Nombre del Contacto",
        "tls_address_field": "Dirección TLS",
        "create": "Crear",
        "new_conversation_created": "¡Nueva conversación creada!",
        "participants": "participantes",
        "no_messages_yet": "Aún no hay mensajes",
        "type_message": "Escribe un mensaje...",
        "usage_statistics": "Estadísticas de Uso",
        "daily_active_minutes": "Minutos Activos Diarios",
        "average_transaction_size": "Tamaño Promedio de Transacción",
        "total_transactions": "Total de Transacciones",
        "total_volume": "Volumen Total",
        "report_bug_title": "Reportar Error",
        "bug_details": "Detalles del Error",
        "category": "Categoría",
        "describe_bug": "Describe el error...",
        "submit": "Enviar",
        "bug_submitted": "¡Error reportado exitosamente!"
    ]
    
    // French strings
    private static let frenchStrings: [String: String] = [
        "profile_settings": "Profil et Paramètres",
        "personal_information": "Informations Personnelles",
        "display_name": "Nom d'Affichage",
        "bio": "Biographie",
        "location": "Localisation",
        "edit": "Modifier",
        "not_set": "Non défini",
        "tap_to_upload_photo": "Appuyez pour télécharger une photo",
        "wallet_information": "Informations du Portefeuille",
        "tls_address": "Adresse TLS",
        "tap_to_copy": "Appuyez pour copier",
        "subscription": "Abonnement",
        "active": "Actif",
        "inactive": "Inactif",
        "ai_status": "Statut IA",
        "xai_grok_integration": "Intégration xAI Grok",
        "ai_features_configured": "Les fonctionnalités IA sont configurées automatiquement",
        "security_sessions": "Sécurité et Sessions",
        "biometric_authentication": "Authentification Biométrique",
        "manage_sessions": "Gérer les Sessions",
        "preferences": "Préférences",
        "language": "Langue",
        "currency": "Devise",
        "theme": "Thème",
        "analytics": "Analytiques",
        "view_usage_analytics": "Voir les Analytiques d'Utilisation",
        "support_help": "Support et Aide",
        "report_bug": "Signaler un Bug",
        "speak_with_team": "Parler avec l'Équipe",
        "save_changes": "Enregistrer les Modifications",
        "unsaved_changes": "Modifications Non Enregistrées",
        "unsaved_changes_message": "Vous avez des modifications non enregistrées. Voulez-vous enregistrer avant de partir ?",
        "save": "Enregistrer",
        "discard": "Ignorer",
        "cancel": "Annuler",
        "edit_info": "Modifier les Informations",
        "display_name_placeholder": "Nom d'Affichage",
        "bio_placeholder": "Biographie",
        "location_placeholder": "Localisation",
        "back": "Retour",
        "ok": "OK",
        "error": "Erreur",
        "success": "Succès",
        "loading": "Chargement...",
        "coming_soon": "Bientôt Disponible",
        "home": "Accueil",
        "messages": "Messages",
        "profile": "Profil",
        "your_ai_assistant": "Votre Assistant IA",
        "sign_in": "Se Connecter",
        "create_new_account": "Créer un Nouveau Compte",
        "enter_wallet_address": "Entrez l'Adresse du Portefeuille",
        "enter_mnemonic": "Entrez le Mnémonique",
        "both_required": "L'adresse et le mnémonique sont requis",
        "invalid_credentials": "Adresse ou mnémonique invalides",
        "address_copied": "Adresse copiée dans le presse-papiers !",
        "new_chat": "Nouveau Chat",
        "contact_information": "Informations de Contact",
        "contact_name": "Nom du Contact",
        "tls_address_field": "Adresse TLS",
        "create": "Créer",
        "new_conversation_created": "Nouvelle conversation créée !",
        "participants": "participants",
        "no_messages_yet": "Aucun message pour le moment",
        "type_message": "Tapez un message...",
        "usage_statistics": "Statistiques d'Utilisation",
        "daily_active_minutes": "Minutes Actives Quotidiennes",
        "average_transaction_size": "Taille Moyenne des Transactions",
        "total_transactions": "Total des Transactions",
        "total_volume": "Volume Total",
        "report_bug_title": "Signaler un Bug",
        "bug_details": "Détails du Bug",
        "category": "Catégorie",
        "describe_bug": "Décrivez le bug...",
        "submit": "Soumettre",
        "bug_submitted": "Bug signalé avec succès !"
    ]
    
    // German strings
    private static let germanStrings: [String: String] = [
        "profile_settings": "Profil & Einstellungen",
        "personal_information": "Persönliche Informationen",
        "display_name": "Anzeigename",
        "bio": "Biografie",
        "location": "Standort",
        "edit": "Bearbeiten",
        "not_set": "Nicht gesetzt",
        "tap_to_upload_photo": "Tippen Sie, um Foto hochzuladen",
        "wallet_information": "Wallet-Informationen",
        "tls_address": "TLS-Adresse",
        "tap_to_copy": "Tippen Sie zum Kopieren",
        "subscription": "Abonnement",
        "active": "Aktiv",
        "inactive": "Inaktiv",
        "ai_status": "KI-Status",
        "xai_grok_integration": "xAI Grok Integration",
        "ai_features_configured": "KI-Funktionen werden automatisch konfiguriert",
        "security_sessions": "Sicherheit & Sessions",
        "biometric_authentication": "Biometrische Authentifizierung",
        "manage_sessions": "Sessions verwalten",
        "preferences": "Einstellungen",
        "language": "Sprache",
        "currency": "Währung",
        "theme": "Design",
        "analytics": "Analytik",
        "view_usage_analytics": "Nutzungsanalytik anzeigen",
        "support_help": "Support & Hilfe",
        "report_bug": "Fehler melden",
        "speak_with_team": "Mit Team sprechen",
        "save_changes": "Änderungen speichern",
        "unsaved_changes": "Ungespeicherte Änderungen",
        "unsaved_changes_message": "Sie haben ungespeicherte Änderungen. Möchten Sie vor dem Verlassen speichern?",
        "save": "Speichern",
        "discard": "Verwerfen",
        "cancel": "Abbrechen",
        "edit_info": "Informationen bearbeiten",
        "display_name_placeholder": "Anzeigename",
        "bio_placeholder": "Biografie",
        "location_placeholder": "Standort",
        "back": "Zurück",
        "ok": "OK",
        "error": "Fehler",
        "success": "Erfolg",
        "loading": "Lädt...",
        "coming_soon": "Demnächst verfügbar",
        "home": "Startseite",
        "messages": "Nachrichten",
        "profile": "Profil",
        "your_ai_assistant": "Ihr KI-Assistent",
        "sign_in": "Anmelden",
        "create_new_account": "Neues Konto erstellen",
        "enter_wallet_address": "Wallet-Adresse eingeben",
        "enter_mnemonic": "Mnemonic eingeben",
        "both_required": "Adresse und Mnemonic sind erforderlich",
        "invalid_credentials": "Ungültige Adresse oder Mnemonic",
        "address_copied": "Adresse in Zwischenablage kopiert!",
        "new_chat": "Neuer Chat",
        "contact_information": "Kontaktinformationen",
        "contact_name": "Kontaktname",
        "tls_address_field": "TLS-Adresse",
        "create": "Erstellen",
        "new_conversation_created": "Neue Konversation erstellt!",
        "participants": "Teilnehmer",
        "no_messages_yet": "Noch keine Nachrichten",
        "type_message": "Nachricht eingeben...",
        "usage_statistics": "Nutzungsstatistiken",
        "daily_active_minutes": "Tägliche aktive Minuten",
        "average_transaction_size": "Durchschnittliche Transaktionsgröße",
        "total_transactions": "Gesamte Transaktionen",
        "total_volume": "Gesamtvolumen",
        "report_bug_title": "Fehler melden",
        "bug_details": "Fehlerdetails",
        "category": "Kategorie",
        "describe_bug": "Beschreiben Sie den Fehler...",
        "submit": "Senden",
        "bug_submitted": "Fehler erfolgreich gemeldet!"
    ]
    
    // Chinese strings
    private static let chineseStrings: [String: String] = [
        "profile_settings": "个人资料和设置",
        "personal_information": "个人信息",
        "display_name": "显示名称",
        "bio": "个人简介",
        "location": "位置",
        "edit": "编辑",
        "not_set": "未设置",
        "tap_to_upload_photo": "点击上传照片",
        "wallet_information": "钱包信息",
        "tls_address": "TLS地址",
        "tap_to_copy": "点击复制",
        "subscription": "订阅",
        "active": "活跃",
        "inactive": "非活跃",
        "ai_status": "AI状态",
        "xai_grok_integration": "xAI Grok集成",
        "ai_features_configured": "AI功能自动配置",
        "security_sessions": "安全和会话",
        "biometric_authentication": "生物识别认证",
        "manage_sessions": "管理会话",
        "preferences": "偏好设置",
        "language": "语言",
        "currency": "货币",
        "theme": "主题",
        "analytics": "分析",
        "view_usage_analytics": "查看使用分析",
        "support_help": "支持和帮助",
        "report_bug": "报告错误",
        "speak_with_team": "与团队交流",
        "save_changes": "保存更改",
        "unsaved_changes": "未保存的更改",
        "unsaved_changes_message": "您有未保存的更改。离开前是否要保存？",
        "save": "保存",
        "discard": "丢弃",
        "cancel": "取消",
        "edit_info": "编辑信息",
        "display_name_placeholder": "显示名称",
        "bio_placeholder": "个人简介",
        "location_placeholder": "位置",
        "back": "返回",
        "ok": "确定",
        "error": "错误",
        "success": "成功",
        "loading": "加载中...",
        "coming_soon": "即将推出",
        "home": "首页",
        "messages": "消息",
        "profile": "个人资料",
        "your_ai_assistant": "您的AI助手",
        "sign_in": "登录",
        "create_new_account": "创建新账户",
        "enter_wallet_address": "输入钱包地址",
        "enter_mnemonic": "输入助记词",
        "both_required": "地址和助记词都是必需的",
        "invalid_credentials": "无效的地址或助记词",
        "address_copied": "地址已复制到剪贴板！",
        "new_chat": "新聊天",
        "contact_information": "联系信息",
        "contact_name": "联系人姓名",
        "tls_address_field": "TLS地址",
        "create": "创建",
        "new_conversation_created": "新对话已创建！",
        "participants": "参与者",
        "no_messages_yet": "暂无消息",
        "type_message": "输入消息...",
        "usage_statistics": "使用统计",
        "daily_active_minutes": "每日活跃分钟",
        "average_transaction_size": "平均交易大小",
        "total_transactions": "总交易数",
        "total_volume": "总交易量",
        "report_bug_title": "报告错误",
        "bug_details": "错误详情",
        "category": "类别",
        "describe_bug": "描述错误...",
        "submit": "提交",
        "bug_submitted": "错误报告提交成功！"
    ]
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizedString.localized(self)
    }
} 
