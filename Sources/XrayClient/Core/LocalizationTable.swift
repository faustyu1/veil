import Foundation

extension Loc {
    /// Translation table: English key → [language code: translation].
    /// Languages: ru, zh, es, hi, ar, fr, pt, de, ja, id, tr.
    static let table: [String: [String: String]] = [

        // MARK: Connection status
        "Connected": [
            "ru": "Подключено", "zh": "已连接", "es": "Conectado", "hi": "कनेक्टेड",
            "ar": "متصل", "fr": "Connecté", "pt": "Conectado", "de": "Verbunden",
            "ja": "接続済み", "id": "Terhubung", "tr": "Bağlandı"],
        "Connecting…": [
            "ru": "Подключение…", "zh": "连接中…", "es": "Conectando…", "hi": "कनेक्ट हो रहा है…",
            "ar": "جارٍ الاتصال…", "fr": "Connexion…", "pt": "Conectando…", "de": "Verbinde…",
            "ja": "接続中…", "id": "Menghubungkan…", "tr": "Bağlanıyor…"],
        "Disconnected": [
            "ru": "Отключено", "zh": "已断开", "es": "Desconectado", "hi": "डिस्कनेक्टेड",
            "ar": "غير متصل", "fr": "Déconnecté", "pt": "Desconectado", "de": "Getrennt",
            "ja": "切断済み", "id": "Terputus", "tr": "Bağlantı kesildi"],

        // MARK: Buttons / actions
        "Connect": [
            "ru": "Подключить", "zh": "连接", "es": "Conectar", "hi": "कनेक्ट",
            "ar": "اتصال", "fr": "Connecter", "pt": "Conectar", "de": "Verbinden",
            "ja": "接続", "id": "Hubungkan", "tr": "Bağlan"],
        "Disconnect": [
            "ru": "Отключить", "zh": "断开", "es": "Desconectar", "hi": "डिस्कनेक्ट",
            "ar": "قطع الاتصال", "fr": "Déconnecter", "pt": "Desconectar", "de": "Trennen",
            "ja": "切断", "id": "Putuskan", "tr": "Bağlantıyı kes"],
        "Select a server": [
            "ru": "Выберите сервер", "zh": "选择服务器", "es": "Selecciona un servidor",
            "hi": "सर्वर चुनें", "ar": "اختر خادمًا", "fr": "Choisir un serveur",
            "pt": "Selecione um servidor", "de": "Server wählen", "ja": "サーバーを選択",
            "id": "Pilih server", "tr": "Bir sunucu seçin"],
        "Cancel": [
            "ru": "Отмена", "zh": "取消", "es": "Cancelar", "hi": "रद्द करें",
            "ar": "إلغاء", "fr": "Annuler", "pt": "Cancelar", "de": "Abbrechen",
            "ja": "キャンセル", "id": "Batal", "tr": "İptal"],
        "Done": [
            "ru": "Готово", "zh": "完成", "es": "Listo", "hi": "हो गया",
            "ar": "تم", "fr": "Terminé", "pt": "Concluído", "de": "Fertig",
            "ja": "完了", "id": "Selesai", "tr": "Bitti"],
        "Add": [
            "ru": "Добавить", "zh": "添加", "es": "Añadir", "hi": "जोड़ें",
            "ar": "إضافة", "fr": "Ajouter", "pt": "Adicionar", "de": "Hinzufügen",
            "ja": "追加", "id": "Tambah", "tr": "Ekle"],
        "Remove": [
            "ru": "Удалить", "zh": "移除", "es": "Eliminar", "hi": "हटाएं",
            "ar": "إزالة", "fr": "Supprimer", "pt": "Remover", "de": "Entfernen",
            "ja": "削除", "id": "Hapus", "tr": "Kaldır"],
        "Delete": [
            "ru": "Удалить", "zh": "删除", "es": "Borrar", "hi": "हटाएं",
            "ar": "حذف", "fr": "Supprimer", "pt": "Excluir", "de": "Löschen",
            "ja": "削除", "id": "Hapus", "tr": "Sil"],
        "Fetch": [
            "ru": "Загрузить", "zh": "获取", "es": "Obtener", "hi": "लाएं",
            "ar": "جلب", "fr": "Récupérer", "pt": "Buscar", "de": "Abrufen",
            "ja": "取得", "id": "Ambil", "tr": "Getir"],
        "Save": [
            "ru": "Сохранить", "zh": "保存", "es": "Guardar", "hi": "सहेजें",
            "ar": "حفظ", "fr": "Enregistrer", "pt": "Salvar", "de": "Speichern",
            "ja": "保存", "id": "Simpan", "tr": "Kaydet"],

        // MARK: Toolbar / footer
        "Subscription": [
            "ru": "Подписка", "zh": "订阅", "es": "Suscripción", "hi": "सदस्यता",
            "ar": "اشتراك", "fr": "Abonnement", "pt": "Assinatura", "de": "Abonnement",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelik"],
        "Refresh": [
            "ru": "Обновить", "zh": "刷新", "es": "Actualizar", "hi": "ताज़ा करें",
            "ar": "تحديث", "fr": "Actualiser", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Segarkan", "tr": "Yenile"],
        "Test Ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Log": [
            "ru": "Лог", "zh": "日志", "es": "Registro", "hi": "लॉग",
            "ar": "السجل", "fr": "Journal", "pt": "Registro", "de": "Protokoll",
            "ja": "ログ", "id": "Log", "tr": "Günlük"],
        "Settings": [
            "ru": "Настройки", "zh": "设置", "es": "Ajustes", "hi": "सेटिंग्स",
            "ar": "الإعدادات", "fr": "Réglages", "pt": "Configurações", "de": "Einstellungen",
            "ja": "設定", "id": "Pengaturan", "tr": "Ayarlar"],

        // MARK: Search / filter
        "Search servers…": [
            "ru": "Поиск серверов…", "zh": "搜索服务器…", "es": "Buscar servidores…",
            "hi": "सर्वर खोजें…", "ar": "البحث عن خوادم…", "fr": "Rechercher des serveurs…",
            "pt": "Buscar servidores…", "de": "Server suchen…", "ja": "サーバー検索…",
            "id": "Cari server…", "tr": "Sunucu ara…"],
        "Alive": [
            "ru": "Живые", "zh": "在线", "es": "Activos", "hi": "सक्रिय",
            "ar": "نشط", "fr": "Actifs", "pt": "Ativos", "de": "Aktiv",
            "ja": "応答", "id": "Aktif", "tr": "Aktif"],
        "By ping": [
            "ru": "По пингу", "zh": "按延迟", "es": "Por ping", "hi": "पिंग अनुसार",
            "ar": "حسب البينغ", "fr": "Par ping", "pt": "Por ping", "de": "Nach Ping",
            "ja": "Ping順", "id": "Per ping", "tr": "Ping'e göre"],

        // MARK: Empty state
        "No servers yet": [
            "ru": "Пока нет серверов", "zh": "暂无服务器", "es": "Aún no hay servidores",
            "hi": "अभी कोई सर्वर नहीं", "ar": "لا توجد خوادم بعد", "fr": "Aucun serveur",
            "pt": "Nenhum servidor ainda", "de": "Noch keine Server", "ja": "サーバーがありません",
            "id": "Belum ada server", "tr": "Henüz sunucu yok"],
        "Add a subscription or paste a link to get started.": [
            "ru": "Добавьте подписку или вставьте ссылку, чтобы начать.",
            "zh": "添加订阅或粘贴链接以开始。", "es": "Añade una suscripción o pega un enlace para empezar.",
            "hi": "शुरू करने के लिए सदस्यता जोड़ें या लिंक पेस्ट करें।",
            "ar": "أضف اشتراكًا أو ألصق رابطًا للبدء.", "fr": "Ajoutez un abonnement ou collez un lien pour commencer.",
            "pt": "Adicione uma assinatura ou cole um link para começar.",
            "de": "Abonnement hinzufügen oder Link einfügen, um zu starten.",
            "ja": "サブスクを追加するかリンクを貼り付けて開始します。",
            "id": "Tambahkan langganan atau tempel tautan untuk memulai.",
            "tr": "Başlamak için abonelik ekleyin veya bağlantı yapıştırın."],
        // MARK: Add sheet
        // The value is the same in every language: it is a list of URL schemes,
        // and an example of what the box accepts rather than prose.
        "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub": [
            "ru": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "zh": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "es": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "hi": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "ar": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "fr": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "pt": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "de": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "ja": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "id": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub",
            "tr": "vless:// · vmess:// · trojan:// · ss:// · wireguard:// · https://…/sub"],

        // MARK: Server group menu
        "Test ping": [
            "ru": "Тест пинга", "zh": "测试延迟", "es": "Probar ping", "hi": "पिंग जांचें",
            "ar": "اختبار البينغ", "fr": "Tester le ping", "pt": "Testar ping", "de": "Ping testen",
            "ja": "Ping測定", "id": "Uji ping", "tr": "Ping testi"],
        "Test ping (group)": [
            "ru": "Тест пинга (группа)", "zh": "测试延迟（组）", "es": "Probar ping (grupo)",
            "hi": "पिंग जांचें (समूह)", "ar": "اختبار البينغ (مجموعة)", "fr": "Tester le ping (groupe)",
            "pt": "Testar ping (grupo)", "de": "Ping testen (Gruppe)", "ja": "Ping測定（グループ）",
            "id": "Uji ping (grup)", "tr": "Ping testi (grup)"],
        "Refresh now": [
            "ru": "Обновить сейчас", "zh": "立即刷新", "es": "Actualizar ahora",
            "hi": "अभी ताज़ा करें", "ar": "تحديث الآن", "fr": "Actualiser maintenant",
            "pt": "Atualizar agora", "de": "Jetzt aktualisieren", "ja": "今すぐ更新",
            "id": "Segarkan sekarang", "tr": "Şimdi yenile"],
        "Auto-update": [
            "ru": "Автообновление", "zh": "自动更新", "es": "Auto-actualizar",
            "hi": "स्वतः अपडेट", "ar": "تحديث تلقائي", "fr": "Mise à jour auto",
            "pt": "Atualização automática", "de": "Auto-Update", "ja": "自動更新",
            "id": "Pembaruan otomatis", "tr": "Otomatik güncelleme"],
        "Switch here": [
            "ru": "Переключить сюда", "zh": "切换到此", "es": "Cambiar aquí",
            "hi": "यहां स्विच करें", "ar": "التبديل هنا", "fr": "Basculer ici",
            "pt": "Mudar para aqui", "de": "Hierhin wechseln", "ja": "ここに切替",
            "id": "Beralih ke sini", "tr": "Buraya geç"],

        // MARK: Add server sheet
        "Add Server(s)": [
            "ru": "Добавить сервер(ы)", "zh": "添加服务器", "es": "Añadir servidor(es)",
            "hi": "सर्वर जोड़ें", "ar": "إضافة خوادم", "fr": "Ajouter des serveurs",
            "pt": "Adicionar servidor(es)", "de": "Server hinzufügen", "ja": "サーバー追加",
            "id": "Tambah server", "tr": "Sunucu ekle"],
        "Paste one or more links (vless://, vmess://, trojan://, ss://). One per line.": [
            "ru": "Вставьте одну или несколько ссылок (vless://, vmess://, trojan://, ss://). По одной на строку.",
            "zh": "粘贴一个或多个链接（vless://、vmess://、trojan://、ss://），每行一个。",
            "es": "Pega uno o más enlaces (vless://, vmess://, trojan://, ss://). Uno por línea.",
            "hi": "एक या अधिक लिंक पेस्ट करें (vless://, vmess://, trojan://, ss://)। प्रति पंक्ति एक।",
            "ar": "ألصق رابطًا واحدًا أو أكثر (vless://، vmess://، trojan://، ss://). واحد لكل سطر.",
            "fr": "Collez un ou plusieurs liens (vless://, vmess://, trojan://, ss://). Un par ligne.",
            "pt": "Cole um ou mais links (vless://, vmess://, trojan://, ss://). Um por linha.",
            "de": "Einen oder mehrere Links einfügen (vless://, vmess://, trojan://, ss://). Einer pro Zeile.",
            "ja": "1つ以上のリンクを貼り付け（vless://、vmess://、trojan://、ss://）。1行に1つ。",
            "id": "Tempel satu atau beberapa tautan (vless://, vmess://, trojan://, ss://). Satu per baris.",
            "tr": "Bir veya daha fazla bağlantı yapıştırın (vless://, vmess://, trojan://, ss://). Her satıra bir tane."],
        "No valid links found. Check the format.": [
            "ru": "Не найдено корректных ссылок. Проверьте формат.",
            "zh": "未找到有效链接。请检查格式。", "es": "No se encontraron enlaces válidos. Comprueba el formato.",
            "hi": "कोई मान्य लिंक नहीं मिला। प्रारूप जांचें।", "ar": "لم يتم العثور على روابط صالحة. تحقق من التنسيق.",
            "fr": "Aucun lien valide trouvé. Vérifiez le format.", "pt": "Nenhum link válido encontrado. Verifique o formato.",
            "de": "Keine gültigen Links gefunden. Format prüfen.", "ja": "有効なリンクがありません。形式を確認してください。",
            "id": "Tidak ada tautan valid. Periksa formatnya.", "tr": "Geçerli bağlantı bulunamadı. Biçimi kontrol edin."],
        "Each subscription becomes its own profile group.": [
            "ru": "Каждая подписка становится отдельной группой профиля.",
            "zh": "每个订阅成为独立的配置组。", "es": "Cada suscripción se convierte en su propio grupo.",
            "hi": "प्रत्येक सदस्यता अपना प्रोफ़ाइल समूह बनती है।", "ar": "يصبح كل اشتراك مجموعة ملف خاصة به.",
            "fr": "Chaque abonnement devient son propre groupe.", "pt": "Cada assinatura vira seu próprio grupo.",
            "de": "Jedes Abonnement wird zu einer eigenen Gruppe.", "ja": "各サブスクは独自のプロファイルグループになります。",
            "id": "Setiap langganan menjadi grup profilnya sendiri.", "tr": "Her abonelik kendi profil grubu olur."],
        "Name (optional)": [
            "ru": "Название (необязательно)", "zh": "名称（可选）", "es": "Nombre (opcional)",
            "hi": "नाम (वैकल्पिक)", "ar": "الاسم (اختياري)", "fr": "Nom (facultatif)",
            "pt": "Nome (opcional)", "de": "Name (optional)", "ja": "名前（任意）",
            "id": "Nama (opsional)", "tr": "Ad (isteğe bağlı)"],

        // MARK: Settings sections
        "Tunnel": [
            "ru": "Туннель", "zh": "隧道", "es": "Túnel", "hi": "टनल",
            "ar": "النفق", "fr": "Tunnel", "pt": "Túnel", "de": "Tunnel",
            "ja": "トンネル", "id": "Terowongan", "tr": "Tünel"],
        "Mode": [
            "ru": "Режим", "zh": "模式", "es": "Modo", "hi": "मोड",
            "ar": "الوضع", "fr": "Mode", "pt": "Modo", "de": "Modus",
            "ja": "モード", "id": "Mode", "tr": "Mod"],
        "Appearance": [
            "ru": "Оформление", "zh": "外观", "es": "Apariencia", "hi": "रूप",
            "ar": "المظهر", "fr": "Apparence", "pt": "Aparência", "de": "Erscheinungsbild",
            "ja": "外観", "id": "Tampilan", "tr": "Görünüm"],
        "Theme": [
            "ru": "Тема", "zh": "主题", "es": "Tema", "hi": "थीम",
            "ar": "السمة", "fr": "Thème", "pt": "Tema", "de": "Design",
            "ja": "テーマ", "id": "Tema", "tr": "Tema"],
        "Language": [
            "ru": "Язык", "zh": "语言", "es": "Idioma", "hi": "भाषा",
            "ar": "اللغة", "fr": "Langue", "pt": "Idioma", "de": "Sprache",
            "ja": "言語", "id": "Bahasa", "tr": "Dil"],
        "Subscriptions": [
            "ru": "Подписки", "zh": "订阅", "es": "Suscripciones", "hi": "सदस्यताएं",
            "ar": "الاشتراكات", "fr": "Abonnements", "pt": "Assinaturas", "de": "Abonnements",
            "ja": "サブスク", "id": "Langganan", "tr": "Abonelikler"],
        "Auto-update subscriptions": [
            "ru": "Автообновление подписок", "zh": "自动更新订阅", "es": "Auto-actualizar suscripciones",
            "hi": "सदस्यताएं स्वतः अपडेट करें", "ar": "تحديث الاشتراكات تلقائيًا", "fr": "Mettre à jour les abonnements auto",
            "pt": "Atualizar assinaturas automaticamente", "de": "Abos automatisch aktualisieren",
            "ja": "サブスクを自動更新", "id": "Perbarui langganan otomatis", "tr": "Abonelikleri otomatik güncelle"],
        "Send HWID with subscription requests": [
            "ru": "Отправлять HWID с запросами подписки", "zh": "订阅请求附带 HWID", "es": "Enviar HWID con solicitudes de suscripción",
            "hi": "सदस्यता अनुरोधों के साथ HWID भेजें", "ar": "إرسال HWID مع طلبات الاشتراك", "fr": "Envoyer le HWID avec les demandes d'abonnement",
            "pt": "Enviar HWID com solicitações de assinatura", "de": "HWID mit Abo-Anfragen senden",
            "ja": "サブスクリクエストにHWIDを送信", "id": "Kirim HWID dengan permintaan langganan", "tr": "Abonelik istekleriyle HWID gönder"],
        "Identifies this device to providers that require it.": [
            "ru": "Идентифицирует устройство для провайдеров, которым это требуется.", "zh": "为需要识别的提供商标识此设备。", "es": "Identifica este dispositivo para los proveedores que lo requieren.",
            "hi": "इस डिवाइस को आवश्यक प्रदाताओं के लिए पहचानता है।", "ar": "يحدد هذا الجهاز للمزودين الذين يتطلبون ذلك.", "fr": "Identifie cet appareil auprès des fournisseurs qui l'exigent.",
            "pt": "Identifica este dispositivo para provedores que exigem.", "de": "Identifiziert dieses Gerät bei Anbietern, die dies verlangen.",
            "ja": "必要なプロバイダーにこのデバイスを識別させます。", "id": "Mengidentifikasi perangkat ini untuk penyedia yang memerlukannya.", "tr": "Bu cihazı gerektiren sağlayıcılar için tanımlar."],
        "Window": [
            "ru": "Окно", "zh": "窗口", "es": "Ventana", "hi": "विंडो",
            "ar": "النافذة", "fr": "Fenêtre", "pt": "Janela", "de": "Fenster",
            "ja": "ウィンドウ", "id": "Jendela", "tr": "Pencere"],
        "Close button hides to menu bar": [
            "ru": "Кнопка закрытия сворачивает в меню-бар",
            "zh": "关闭按钮隐藏到菜单栏", "es": "El botón cerrar oculta en la barra de menús",
            "hi": "बंद बटन मेन्यू बार में छुपाता है", "ar": "زر الإغلاق يخفي إلى شريط القوائم",
            "fr": "Le bouton fermer masque dans la barre de menus", "pt": "Botão fechar oculta na barra de menus",
            "de": "Schließen-Knopf blendet in Menüleiste aus", "ja": "閉じるボタンでメニューバーに格納",
            "id": "Tombol tutup sembunyi ke bilah menu", "tr": "Kapat düğmesi menü çubuğuna gizler"],
        "SOCKS port": [
            "ru": "Порт SOCKS", "zh": "SOCKS 端口", "es": "Puerto SOCKS", "hi": "SOCKS पोर्ट",
            "ar": "منفذ SOCKS", "fr": "Port SOCKS", "pt": "Porta SOCKS", "de": "SOCKS-Port",
            "ja": "SOCKSポート", "id": "Port SOCKS", "tr": "SOCKS portu"],
        "HTTP port": [
            "ru": "Порт HTTP", "zh": "HTTP 端口", "es": "Puerto HTTP", "hi": "HTTP पोर्ट",
            "ar": "منفذ HTTP", "fr": "Port HTTP", "pt": "Porta HTTP", "de": "HTTP-Port",
            "ja": "HTTPポート", "id": "Port HTTP", "tr": "HTTP portu"],
        "Log level": [
            "ru": "Уровень логов", "zh": "日志级别", "es": "Nivel de registro", "hi": "लॉग स्तर",
            "ar": "مستوى السجل", "fr": "Niveau de journal", "pt": "Nível de log", "de": "Log-Level",
            "ja": "ログレベル", "id": "Tingkat log", "tr": "Günlük düzeyi"],
        "Auto-connect on launch": [
            "ru": "Автоподключение при запуске", "zh": "启动时自动连接",
            "es": "Conectar al iniciar", "hi": "लॉन्च पर स्वतः कनेक्ट",
            "ar": "اتصال تلقائي عند البدء", "fr": "Connexion auto au démarrage",
            "pt": "Conectar ao iniciar", "de": "Auto-Verbindung beim Start",
            "ja": "起動時に自動接続", "id": "Sambung otomatis saat mulai",
            "tr": "Başlangıçta otomatik bağlan"],
        "Helper installed": [
            "ru": "Хелпер установлен", "zh": "助手已安装", "es": "Asistente instalado",
            "hi": "हेल्पर स्थापित", "ar": "تم تثبيت المساعد", "fr": "Assistant installé",
            "pt": "Auxiliar instalado", "de": "Helfer installiert", "ja": "ヘルパー導入済み",
            "id": "Helper terpasang", "tr": "Yardımcı kuruldu"],
        "Helper not installed": [
            "ru": "Хелпер не установлен", "zh": "助手未安装", "es": "Asistente no instalado",
            "hi": "हेल्पर स्थापित नहीं", "ar": "المساعد غير مثبت", "fr": "Assistant non installé",
            "pt": "Auxiliar não instalado", "de": "Helfer nicht installiert", "ja": "ヘルパー未導入",
            "id": "Helper belum terpasang", "tr": "Yardımcı kurulu değil"],
        "Install": [
            "ru": "Установить", "zh": "安装", "es": "Instalar", "hi": "इंस्टॉल",
            "ar": "تثبيت", "fr": "Installer", "pt": "Instalar", "de": "Installieren",
            "ja": "インストール", "id": "Pasang", "tr": "Kur"],

        // MARK: Menu bar
        "Open Window": [
            "ru": "Открыть окно", "zh": "打开窗口", "es": "Abrir ventana", "hi": "विंडो खोलें",
            "ar": "فتح النافذة", "fr": "Ouvrir la fenêtre", "pt": "Abrir janela", "de": "Fenster öffnen",
            "ja": "ウィンドウを開く", "id": "Buka jendela", "tr": "Pencereyi aç"],
        "Quit Veil": [
            "ru": "Выйти из Veil", "zh": "退出 Veil", "es": "Salir de Veil", "hi": "Veil छोड़ें",
            "ar": "إنهاء Veil", "fr": "Quitter Veil", "pt": "Sair do Veil", "de": "Veil beenden",
            "ja": "Veilを終了", "id": "Keluar dari Veil", "tr": "Veil'den çık"],

        // MARK: Routing
        "Routing": [
            "ru": "Маршрутизация", "zh": "路由", "es": "Enrutamiento", "hi": "रूटिंग",
            "ar": "التوجيه", "fr": "Routage", "pt": "Roteamento", "de": "Routing",
            "ja": "ルーティング", "id": "Perutean", "tr": "Yönlendirme"],
        "Configure…": [
            "ru": "Настроить…", "zh": "配置…", "es": "Configurar…", "hi": "कॉन्फ़िगर…",
            "ar": "تكوين…", "fr": "Configurer…", "pt": "Configurar…", "de": "Konfigurieren…",
            "ja": "設定…", "id": "Konfigurasi…", "tr": "Yapılandır…"],
        "Preset": [
            "ru": "Пресет", "zh": "预设", "es": "Preajuste", "hi": "प्रीसेट",
            "ar": "إعداد مسبق", "fr": "Préréglage", "pt": "Predefinição", "de": "Voreinstellung",
            "ja": "プリセット", "id": "Praatur", "tr": "Önayar"],
        "Block ads & trackers": [
            "ru": "Блокировать рекламу и трекеры", "zh": "屏蔽广告和追踪器",
            "es": "Bloquear anuncios y rastreadores", "hi": "विज्ञापन और ट्रैकर ब्लॉक करें",
            "ar": "حظر الإعلانات والمتتبعات", "fr": "Bloquer pubs et traqueurs",
            "pt": "Bloquear anúncios e rastreadores", "de": "Werbung & Tracker blockieren",
            "ja": "広告とトラッカーをブロック", "id": "Blokir iklan & pelacak",
            "tr": "Reklam ve izleyicileri engelle"],
        "Rule database": [
            "ru": "База правил", "zh": "规则数据库", "es": "Base de reglas", "hi": "नियम डेटाबेस",
            "ar": "قاعدة القواعد", "fr": "Base de règles", "pt": "Base de regras", "de": "Regeldatenbank",
            "ja": "ルールDB", "id": "Basis aturan", "tr": "Kural veritabanı"],
        "Rule database (geosite / geoip)": [
            "ru": "База правил (geosite / geoip)", "zh": "规则数据库（geosite / geoip）",
            "es": "Base de reglas (geosite / geoip)", "hi": "नियम डेटाबेस (geosite / geoip)",
            "ar": "قاعدة القواعد (geosite / geoip)", "fr": "Base de règles (geosite / geoip)",
            "pt": "Base de regras (geosite / geoip)", "de": "Regeldatenbank (geosite / geoip)",
            "ja": "ルールDB（geosite / geoip）", "id": "Basis aturan (geosite / geoip)",
            "tr": "Kural veritabanı (geosite / geoip)"],
        "Downloading…": [
            "ru": "Загрузка…", "zh": "下载中…", "es": "Descargando…", "hi": "डाउनलोड हो रहा है…",
            "ar": "جارٍ التنزيل…", "fr": "Téléchargement…", "pt": "Baixando…", "de": "Lädt herunter…",
            "ja": "ダウンロード中…", "id": "Mengunduh…", "tr": "İndiriliyor…"],
        "Updated": [
            "ru": "Обновлено", "zh": "已更新", "es": "Actualizado", "hi": "अपडेट किया गया",
            "ar": "تم التحديث", "fr": "Mis à jour", "pt": "Atualizado", "de": "Aktualisiert",
            "ja": "更新済み", "id": "Diperbarui", "tr": "Güncellendi"],
        "Not downloaded": [
            "ru": "Не загружено", "zh": "未下载", "es": "No descargado", "hi": "डाउनलोड नहीं किया",
            "ar": "لم يتم التنزيل", "fr": "Non téléchargé", "pt": "Não baixado", "de": "Nicht heruntergeladen",
            "ja": "未ダウンロード", "id": "Belum diunduh", "tr": "İndirilmedi"],
        "Download": [
            "ru": "Загрузить", "zh": "下载", "es": "Descargar", "hi": "डाउनलोड",
            "ar": "تنزيل", "fr": "Télécharger", "pt": "Baixar", "de": "Herunterladen",
            "ja": "ダウンロード", "id": "Unduh", "tr": "İndir"],
        "Update": [
            "ru": "Обновить", "zh": "更新", "es": "Actualizar", "hi": "अपडेट",
            "ar": "تحديث", "fr": "Mettre à jour", "pt": "Atualizar", "de": "Aktualisieren",
            "ja": "更新", "id": "Perbarui", "tr": "Güncelle"],
        "This preset needs the rule database. Download it to use geosite/geoip rules.": [
            "ru": "Этому пресету нужна база правил. Загрузите её для geosite/geoip.",
            "zh": "此预设需要规则数据库。下载后才能使用 geosite/geoip 规则。",
            "es": "Este preajuste necesita la base de reglas. Descárgala para usar geosite/geoip.",
            "hi": "इस प्रीसेट को नियम डेटाबेस चाहिए। geosite/geoip नियमों के लिए डाउनलोड करें।",
            "ar": "يحتاج هذا الإعداد إلى قاعدة القواعد. نزّلها لاستخدام قواعد geosite/geoip.",
            "fr": "Ce préréglage nécessite la base de règles. Téléchargez-la pour geosite/geoip.",
            "pt": "Esta predefinição precisa da base de regras. Baixe-a para usar geosite/geoip.",
            "de": "Diese Voreinstellung benötigt die Regeldatenbank. Lade sie für geosite/geoip herunter.",
            "ja": "このプリセットにはルールDBが必要です。geosite/geoipルールのためにダウンロードしてください。",
            "id": "Praatur ini membutuhkan basis aturan. Unduh untuk memakai aturan geosite/geoip.",
            "tr": "Bu önayar kural veritabanı gerektirir. geosite/geoip için indirin."],
        "Downloaded from GitHub. geosite matches domains, geoip matches IPs by country.": [
            "ru": "Загружается с GitHub. geosite — домены, geoip — IP по странам.",
            "zh": "从 GitHub 下载。geosite 匹配域名，geoip 按国家匹配 IP。",
            "es": "Descargado de GitHub. geosite coincide con dominios, geoip con IP por país.",
            "hi": "GitHub से डाउनलोड। geosite डोमेन, geoip देश के अनुसार IP मैच करता है।",
            "ar": "يتم التنزيل من GitHub. geosite يطابق النطاقات، geoip يطابق IP حسب الدولة.",
            "fr": "Téléchargé depuis GitHub. geosite correspond aux domaines, geoip aux IP par pays.",
            "pt": "Baixado do GitHub. geosite corresponde a domínios, geoip a IPs por país.",
            "de": "Von GitHub geladen. geosite trifft Domains, geoip trifft IPs nach Land.",
            "ja": "GitHubからダウンロード。geositeはドメイン、geoipは国別IPに一致。",
            "id": "Diunduh dari GitHub. geosite cocok dengan domain, geoip dengan IP per negara.",
            "tr": "GitHub'dan indirilir. geosite alan adlarıyla, geoip ülkeye göre IP'lerle eşleşir."],
        "No custom rules. Add one below.": [
            "ru": "Нет своих правил. Добавьте ниже.", "zh": "没有自定义规则。在下方添加。",
            "es": "Sin reglas personalizadas. Añade una abajo.", "hi": "कोई कस्टम नियम नहीं। नीचे जोड़ें।",
            "ar": "لا توجد قواعد مخصصة. أضف واحدة أدناه.", "fr": "Aucune règle personnalisée. Ajoutez-en une ci-dessous.",
            "pt": "Sem regras personalizadas. Adicione uma abaixo.", "de": "Keine eigenen Regeln. Unten hinzufügen.",
            "ja": "カスタムルールがありません。下に追加してください。", "id": "Tidak ada aturan khusus. Tambah di bawah.",
            "tr": "Özel kural yok. Aşağıdan ekleyin."],
        "Add rule": [
            "ru": "Добавить правило", "zh": "添加规则", "es": "Añadir regla", "hi": "नियम जोड़ें",
            "ar": "إضافة قاعدة", "fr": "Ajouter une règle", "pt": "Adicionar regra", "de": "Regel hinzufügen",
            "ja": "ルールを追加", "id": "Tambah aturan", "tr": "Kural ekle"],
        "Custom rules (top to bottom, first match wins)": [
            "ru": "Свои правила (сверху вниз, срабатывает первое)",
            "zh": "自定义规则（自上而下，首条匹配生效）",
            "es": "Reglas personalizadas (de arriba abajo, gana la primera)",
            "hi": "कस्टम नियम (ऊपर से नीचे, पहला मैच लागू)",
            "ar": "قواعد مخصصة (من الأعلى للأسفل، الأول يفوز)",
            "fr": "Règles personnalisées (de haut en bas, la première gagne)",
            "pt": "Regras personalizadas (de cima para baixo, vence a primeira)",
            "de": "Eigene Regeln (oben nach unten, erste Übereinstimmung gewinnt)",
            "ja": "カスタムルール（上から下へ、最初の一致が有効）",
            "id": "Aturan khusus (atas ke bawah, cocok pertama menang)",
            "tr": "Özel kurallar (yukarıdan aşağıya, ilk eşleşme kazanır)"],
        "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.": [
            "ru": "Домены: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "zh": "域名：example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP：1.2.3.0/24、geoip:cn、geoip:private。",
            "es": "Dominios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "hi": "डोमेन: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ar": "النطاقات: example.com، domain:example.com، geosite:category-ads-all، keyword:google. IP: 1.2.3.0/24، geoip:cn، geoip:private.",
            "fr": "Domaines : example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP : 1.2.3.0/24, geoip:cn, geoip:private.",
            "pt": "Domínios: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "de": "Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private.",
            "ja": "ドメイン: example.com、domain:example.com、geosite:category-ads-all、keyword:google。IP: 1.2.3.0/24、geoip:cn、geoip:private。",
            "id": "Domain: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private.",
            "tr": "Alan adları: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IP: 1.2.3.0/24, geoip:cn, geoip:private."],
        "Rule name": [
            "ru": "Название правила", "zh": "规则名称", "es": "Nombre de regla", "hi": "नियम नाम",
            "ar": "اسم القاعدة", "fr": "Nom de la règle", "pt": "Nome da regra", "de": "Regelname",
            "ja": "ルール名", "id": "Nama aturan", "tr": "Kural adı"],
        "Domains": [
            "ru": "Домены", "zh": "域名", "es": "Dominios", "hi": "डोमेन",
            "ar": "النطاقات", "fr": "Domaines", "pt": "Domínios", "de": "Domains",
            "ja": "ドメイン", "id": "Domain", "tr": "Alan adları"],
        "IPs / CIDR": [
            "ru": "IP / CIDR", "zh": "IP / CIDR", "es": "IP / CIDR", "hi": "IP / CIDR",
            "ar": "IP / CIDR", "fr": "IP / CIDR", "pt": "IP / CIDR", "de": "IP / CIDR",
            "ja": "IP / CIDR", "id": "IP / CIDR", "tr": "IP / CIDR"],
        "Port": [
            "ru": "Порт", "zh": "端口", "es": "Puerto", "hi": "पोर्ट",
            "ar": "المنفذ", "fr": "Port", "pt": "Porta", "de": "Port",
            "ja": "ポート", "id": "Port", "tr": "Port"],
        "Reconnect to apply routing changes.": [
            "ru": "Переподключитесь, чтобы применить изменения маршрутизации.",
            "zh": "重新连接以应用路由更改。", "es": "Reconecta para aplicar los cambios de enrutamiento.",
            "hi": "रूटिंग परिवर्तन लागू करने के लिए फिर से कनेक्ट करें।", "ar": "أعد الاتصال لتطبيق تغييرات التوجيه.",
            "fr": "Reconnectez-vous pour appliquer les changements de routage.", "pt": "Reconecte para aplicar as alterações de roteamento.",
            "de": "Neu verbinden, um Routing-Änderungen anzuwenden.", "ja": "ルーティングの変更を適用するには再接続してください。",
            "id": "Sambungkan ulang untuk menerapkan perubahan perutean.", "tr": "Yönlendirme değişikliklerini uygulamak için yeniden bağlanın."],

        // MARK: Manual selection / deletion
        "Select": [
            "ru": "Выбрать", "zh": "选择", "es": "Seleccionar", "hi": "चुनें",
            "ar": "تحديد", "fr": "Sélectionner", "pt": "Selecionar", "de": "Auswählen",
            "ja": "選択", "id": "Pilih", "tr": "Seç"],
        "Select All": [
            "ru": "Выбрать все", "zh": "全选", "es": "Seleccionar todo", "hi": "सभी चुनें",
            "ar": "تحديد الكل", "fr": "Tout sélectionner", "pt": "Selecionar tudo", "de": "Alle auswählen",
            "ja": "すべて選択", "id": "Pilih semua", "tr": "Tümünü seç"],
        "Deselect All": [
            "ru": "Снять выбор", "zh": "取消全选", "es": "Deseleccionar todo", "hi": "चयन हटाएं",
            "ar": "إلغاء تحديد الكل", "fr": "Tout désélectionner", "pt": "Desmarcar tudo", "de": "Auswahl aufheben",
            "ja": "選択解除", "id": "Batalkan semua", "tr": "Seçimi kaldır"],
        "Delete Selected": [
            "ru": "Удалить выбранные", "zh": "删除所选", "es": "Eliminar seleccionados",
            "hi": "चयनित हटाएं", "ar": "حذف المحدد", "fr": "Supprimer la sélection",
            "pt": "Excluir selecionados", "de": "Auswahl löschen", "ja": "選択を削除",
            "id": "Hapus terpilih", "tr": "Seçilenleri sil"],
        "Manual": [
            "ru": "Вручную", "zh": "手动", "es": "Manual", "hi": "मैनुअल",
            "ar": "يدوي", "fr": "Manuel", "pt": "Manual", "de": "Manuell",
            "ja": "手動", "id": "Manual", "tr": "Manuel"],
        "System": [
            "ru": "Системный", "zh": "系统", "es": "Sistema", "hi": "सिस्टम",
            "ar": "النظام", "fr": "Système", "pt": "Sistema", "de": "System",
            "ja": "システム", "id": "Sistem", "tr": "Sistem"],

        // MARK: Enum titles shown in pickers (LogLevel, RoutingPreset, AppAppearance, RuleOutbound, GeoAssetSource)
        "Debug": [
            "ru": "Отладка", "zh": "调试", "es": "Depuración", "hi": "डिबग",
            "ar": "تصحيح", "fr": "Débogage", "pt": "Depuração", "de": "Debug",
            "ja": "デバッグ", "id": "Debug", "tr": "Hata ayıklama"],
        "Info": [
            "ru": "Инфо", "zh": "信息", "es": "Información", "hi": "जानकारी",
            "ar": "معلومات", "fr": "Info", "pt": "Informação", "de": "Info",
            "ja": "情報", "id": "Info", "tr": "Bilgi"],
        "Warning": [
            "ru": "Предупреждения", "zh": "警告", "es": "Advertencia", "hi": "चेतावनी",
            "ar": "تحذير", "fr": "Avertissement", "pt": "Aviso", "de": "Warnung",
            "ja": "警告", "id": "Peringatan", "tr": "Uyarı"],
        "Error": [
            "ru": "Ошибки", "zh": "错误", "es": "Error", "hi": "त्रुटि",
            "ar": "خطأ", "fr": "Erreur", "pt": "Erro", "de": "Fehler",
            "ja": "エラー", "id": "Kesalahan", "tr": "Hata"],
        "None": [
            "ru": "Нет", "zh": "无", "es": "Ninguno", "hi": "कोई नहीं",
            "ar": "بدون", "fr": "Aucun", "pt": "Nenhum", "de": "Keine",
            "ja": "なし", "id": "Tidak ada", "tr": "Yok"],
        "Global": [
            "ru": "Глобально", "zh": "全局", "es": "Global", "hi": "ग्लोबल",
            "ar": "عام", "fr": "Global", "pt": "Global", "de": "Global",
            "ja": "グローバル", "id": "Global", "tr": "Genel"],
        "Bypass LAN": [
            "ru": "В обход LAN", "zh": "绕过局域网", "es": "Omitir LAN", "hi": "LAN बायपास",
            "ar": "تجاوز الشبكة المحلية", "fr": "Contourner le LAN", "pt": "Ignorar LAN", "de": "LAN umgehen",
            "ja": "LAN をバイパス", "id": "Lewati LAN", "tr": "LAN'ı atla"],
        "Bypass China": [
            "ru": "В обход Китая", "zh": "绕过中国", "es": "Omitir China", "hi": "चीन बायपास",
            "ar": "تجاوز الصين", "fr": "Contourner la Chine", "pt": "Ignorar China", "de": "China umgehen",
            "ja": "中国をバイパス", "id": "Lewati Tiongkok", "tr": "Çin'i atla"],
        "Bypass Russia": [
            "ru": "В обход России", "zh": "绕过俄罗斯", "es": "Omitir Rusia", "hi": "रूस बायपास",
            "ar": "تجاوز روسيا", "fr": "Contourner la Russie", "pt": "Ignorar Rússia", "de": "Russland umgehen",
            "ja": "ロシアをバイパス", "id": "Lewati Rusia", "tr": "Rusya'yı atla"],
        "Custom": [
            "ru": "Свои", "zh": "自定义", "es": "Personalizado", "hi": "कस्टम",
            "ar": "مخصص", "fr": "Personnalisé", "pt": "Personalizado", "de": "Eigene",
            "ja": "カスタム", "id": "Kustom", "tr": "Özel"],
        "Light": [
            "ru": "Светлая", "zh": "浅色", "es": "Claro", "hi": "लाइट",
            "ar": "فاتح", "fr": "Clair", "pt": "Claro", "de": "Hell",
            "ja": "ライト", "id": "Terang", "tr": "Açık"],
        "Dark": [
            "ru": "Тёмная", "zh": "深色", "es": "Oscuro", "hi": "डार्क",
            "ar": "داكن", "fr": "Sombre", "pt": "Escuro", "de": "Dunkel",
            "ja": "ダーク", "id": "Gelap", "tr": "Koyu"],
        "Proxy": [
            "ru": "Прокси", "zh": "代理", "es": "Proxy", "hi": "प्रॉक्सी",
            "ar": "الوكيل", "fr": "Proxy", "pt": "Proxy", "de": "Proxy",
            "ja": "プロキシ", "id": "Proxy", "tr": "Proxy"],
        "Direct": [
            "ru": "Напрямую", "zh": "直连", "es": "Directo", "hi": "सीधा",
            "ar": "مباشر", "fr": "Direct", "pt": "Direto", "de": "Direkt",
            "ja": "直接", "id": "Langsung", "tr": "Doğrudan"],
        "Block": [
            "ru": "Блокировать", "zh": "阻止", "es": "Bloquear", "hi": "ब्लॉक",
            "ar": "حظر", "fr": "Bloquer", "pt": "Bloquear", "de": "Blockieren",
            "ja": "ブロック", "id": "Blokir", "tr": "Engelle"],
        "All traffic through the proxy.": [
            "ru": "Весь трафик через прокси.", "zh": "所有流量走代理。", "es": "Todo el tráfico por el proxy.", "hi": "सारा ट्रैफ़िक प्रॉक्सी से।",
            "ar": "كل حركة البيانات عبر الوكيل.", "fr": "Tout le trafic passe par le proxy.", "pt": "Todo o tráfego pelo proxy.", "de": "Gesamter Verkehr über den Proxy.",
            "ja": "すべての通信をプロキシ経由にします。", "id": "Semua lalu lintas lewat proxy.", "tr": "Tüm trafik proxy üzerinden."],
        "Proxy everything except local/LAN addresses.": [
            "ru": "Всё через прокси, кроме локальных адресов.", "zh": "除本地/局域网地址外全部走代理。", "es": "Todo por el proxy salvo las direcciones locales/LAN.", "hi": "लोकल/LAN पतों को छोड़कर सब प्रॉक्सी से।",
            "ar": "كل شيء عبر الوكيل عدا العناوين المحلية.", "fr": "Tout via le proxy sauf les adresses locales/LAN.", "pt": "Tudo pelo proxy exceto endereços locais/LAN.", "de": "Alles über den Proxy außer lokalen/LAN-Adressen.",
            "ja": "ローカル/LAN アドレス以外をプロキシ経由にします。", "id": "Semua lewat proxy kecuali alamat lokal/LAN.", "tr": "Yerel/LAN adresleri dışında her şey proxy üzerinden."],
        "Mainland China sites & LAN go direct, rest via proxy.": [
            "ru": "Сайты Китая и локальная сеть — напрямую, остальное через прокси.", "zh": "中国大陆站点与局域网直连，其余走代理。", "es": "Sitios de China continental y LAN directos, el resto por proxy.", "hi": "मुख्यभूमि चीन की साइटें और LAN सीधे, बाकी प्रॉक्सी से।",
            "ar": "مواقع الصين والشبكة المحلية مباشرة، والباقي عبر الوكيل.", "fr": "Sites de Chine continentale et LAN en direct, le reste via le proxy.", "pt": "Sites da China continental e LAN diretos, o resto pelo proxy.", "de": "Festlandchina-Seiten und LAN direkt, der Rest über den Proxy.",
            "ja": "中国本土のサイトと LAN は直接接続、それ以外はプロキシ経由。", "id": "Situs Tiongkok daratan dan LAN langsung, sisanya lewat proxy.", "tr": "Çin anakarası siteleri ve LAN doğrudan, gerisi proxy üzerinden."],
        "Russian & .ru-gov sites go direct, rest via proxy.": [
            "ru": "Российские и госсайты — напрямую, остальное через прокси.", "zh": "俄罗斯及 .ru 政府站点直连，其余走代理。", "es": "Sitios rusos y gubernamentales directos, el resto por proxy.", "hi": "रूसी और सरकारी साइटें सीधे, बाकी प्रॉक्सी से।",
            "ar": "المواقع الروسية والحكومية مباشرة، والباقي عبر الوكيل.", "fr": "Sites russes et gouvernementaux en direct, le reste via le proxy.", "pt": "Sites russos e governamentais diretos, o resto pelo proxy.", "de": "Russische und Regierungsseiten direkt, der Rest über den Proxy.",
            "ja": "ロシアと政府系サイトは直接接続、それ以外はプロキシ経由。", "id": "Situs Rusia dan pemerintah langsung, sisanya lewat proxy.", "tr": "Rus ve devlet siteleri doğrudan, gerisi proxy üzerinden."],
        "Your own ordered rule list.": [
            "ru": "Ваш собственный упорядоченный список правил.", "zh": "你自己排序的规则列表。", "es": "Tu propia lista ordenada de reglas.", "hi": "आपकी अपनी क्रमबद्ध नियम सूची।",
            "ar": "قائمة قواعدك المرتّبة الخاصة.", "fr": "Votre propre liste de règles ordonnée.", "pt": "Sua própria lista ordenada de regras.", "de": "Ihre eigene, geordnete Regelliste.",
            "ja": "独自の順序付きルールリスト。", "id": "Daftar aturan berurutan milik Anda.", "tr": "Kendi sıralı kural listeniz."],
        "Loyalsoldier (global + CN)": [
            "ru": "Loyalsoldier (мир + Китай)", "zh": "Loyalsoldier（全球 + 中国）", "es": "Loyalsoldier (global + CN)", "hi": "Loyalsoldier (वैश्विक + CN)",
            "ar": "Loyalsoldier (عالمي + الصين)", "fr": "Loyalsoldier (monde + CN)", "pt": "Loyalsoldier (global + CN)", "de": "Loyalsoldier (global + CN)",
            "ja": "Loyalsoldier（全世界 + 中国）", "id": "Loyalsoldier (global + CN)", "tr": "Loyalsoldier (küresel + ÇH)"],
        "runetfreedom (RU)": [
            "ru": "runetfreedom (Россия)", "zh": "runetfreedom（俄罗斯）", "es": "runetfreedom (Rusia)", "hi": "runetfreedom (रूस)",
            "ar": "runetfreedom (روسيا)", "fr": "runetfreedom (Russie)", "pt": "runetfreedom (Rússia)", "de": "runetfreedom (Russland)",
            "ja": "runetfreedom（ロシア）", "id": "runetfreedom (Rusia)", "tr": "runetfreedom (Rusya)"],
        "v2fly (official)": [
            "ru": "v2fly (официальный)", "zh": "v2fly（官方）", "es": "v2fly (oficial)", "hi": "v2fly (आधिकारिक)",
            "ar": "v2fly (رسمي)", "fr": "v2fly (officiel)", "pt": "v2fly (oficial)", "de": "v2fly (offiziell)",
            "ja": "v2fly（公式）", "id": "v2fly (resmi)", "tr": "v2fly (resmî)"],
        "Custom URLs": [
            "ru": "Свои ссылки", "zh": "自定义地址", "es": "URL personalizadas", "hi": "कस्टम URL",
            "ar": "روابط مخصصة", "fr": "URL personnalisées", "pt": "URLs personalizadas", "de": "Eigene URLs",
            "ja": "カスタム URL", "id": "URL kustom", "tr": "Özel adresler"],

        // MARK: iOS app
        "About": [
            "ru": "О программе", "zh": "关于", "es": "Acerca de", "hi": "परिचय",
            "ar": "حول", "fr": "À propos", "pt": "Sobre", "de": "Über",
            "ja": "情報", "id": "Tentang", "tr": "Hakkında"],
        "App version": [
            "ru": "Версия приложения", "zh": "应用版本", "es": "Versión de la app", "hi": "ऐप संस्करण",
            "ar": "إصدار التطبيق", "fr": "Version de l'app", "pt": "Versão do app", "de": "App-Version",
            "ja": "アプリバージョン", "id": "Versi aplikasi", "tr": "Uygulama sürümü"],
        "Block ads": [
            "ru": "Блокировать рекламу", "zh": "拦截广告", "es": "Bloquear anuncios", "hi": "विज्ञापन ब्लॉक करें",
            "ar": "حظر الإعلانات", "fr": "Bloquer les pubs", "pt": "Bloquear anúncios", "de": "Werbung blockieren",
            "ja": "広告をブロック", "id": "Blokir iklan", "tr": "Reklamları engelle"],
        "Blocking": [
            "ru": "Блокировка", "zh": "拦截", "es": "Bloqueo", "hi": "ब्लॉकिंग",
            "ar": "الحظر", "fr": "Blocage", "pt": "Bloqueio", "de": "Blockieren",
            "ja": "ブロック", "id": "Pemblokiran", "tr": "Engelleme"],
        "Changes apply the next time you connect or switch servers.": [
            "ru": "Изменения применятся при следующем подключении или смене сервера.", "zh": "更改将在下次连接或切换服务器时生效。", "es": "Los cambios se aplican la próxima vez que te conectes o cambies de servidor.", "hi": "परिवर्तन अगली बार कनेक्ट करने या सर्वर बदलने पर लागू होंगे।",
            "ar": "تُطبَّق التغييرات عند الاتصال التالي أو عند تبديل الخادم.", "fr": "Les modifications s'appliqueront à la prochaine connexion ou au changement de serveur.", "pt": "As alterações serão aplicadas na próxima conexão ou troca de servidor.", "de": "Änderungen gelten beim nächsten Verbinden oder Serverwechsel.",
            "ja": "変更は次回の接続またはサーバー切り替え時に適用されます。", "id": "Perubahan berlaku saat Anda terhubung berikutnya atau berganti server.", "tr": "Değişiklikler bir sonraki bağlantıda veya sunucu değişiminde uygulanır."],
        "Copy link": [
            "ru": "Скопировать ссылку", "zh": "复制链接", "es": "Copiar enlace", "hi": "लिंक कॉपी करें",
            "ar": "نسخ الرابط", "fr": "Copier le lien", "pt": "Copiar link", "de": "Link kopieren",
            "ja": "リンクをコピー", "id": "Salin tautan", "tr": "Bağlantıyı kopyala"],
        "Could not read that image.": [
            "ru": "Не удалось прочитать изображение.", "zh": "无法读取该图片。", "es": "No se pudo leer la imagen.", "hi": "वह छवि पढ़ी नहीं जा सकी।",
            "ar": "تعذّرت قراءة الصورة.", "fr": "Impossible de lire cette image.", "pt": "Não foi possível ler a imagem.", "de": "Bild konnte nicht gelesen werden.",
            "ja": "画像を読み取れませんでした。", "id": "Tidak dapat membaca gambar itu.", "tr": "Görsel okunamadı."],
        "Could not render a QR code for this server.": [
            "ru": "Не удалось создать QR-код для этого сервера.", "zh": "无法为该服务器生成二维码。", "es": "No se pudo generar el código QR de este servidor.", "hi": "इस सर्वर के लिए QR कोड नहीं बनाया जा सका।",
            "ar": "تعذّر إنشاء رمز QR لهذا الخادم.", "fr": "Impossible de générer le QR code pour ce serveur.", "pt": "Não foi possível gerar o QR code deste servidor.", "de": "QR-Code für diesen Server konnte nicht erstellt werden.",
            "ja": "このサーバーの QR コードを生成できませんでした。", "id": "Tidak dapat membuat kode QR untuk server ini.", "tr": "Bu sunucu için QR kod oluşturulamadı."],
        "Custom rules": [
            "ru": "Свои правила", "zh": "自定义规则", "es": "Reglas personalizadas", "hi": "कस्टम नियम",
            "ar": "قواعد مخصصة", "fr": "Règles personnalisées", "pt": "Regras personalizadas", "de": "Eigene Regeln",
            "ja": "カスタムルール", "id": "Aturan kustom", "tr": "Özel kurallar"],
        "Device ID": [
            "ru": "ID устройства", "zh": "设备 ID", "es": "ID del dispositivo", "hi": "डिवाइस आईडी",
            "ar": "معرّف الجهاز", "fr": "Identifiant de l'appareil", "pt": "ID do dispositivo", "de": "Geräte-ID",
            "ja": "デバイス ID", "id": "ID perangkat", "tr": "Cihaz kimliği"],
        "Download geo databases": [
            "ru": "Скачать geo-базы", "zh": "下载 geo 数据库", "es": "Descargar bases geo", "hi": "geo डेटाबेस डाउनलोड करें",
            "ar": "تنزيل قواعد geo", "fr": "Télécharger les bases geo", "pt": "Baixar bases geo", "de": "Geo-Datenbanken laden",
            "ja": "geo データベースをダウンロード", "id": "Unduh basis data geo", "tr": "Geo veritabanlarını indir"],
        "Enabled": [
            "ru": "Включено", "zh": "已启用", "es": "Activada", "hi": "सक्षम",
            "ar": "مفعّل", "fr": "Activée", "pt": "Ativada", "de": "Aktiviert",
            "ja": "有効", "id": "Aktif", "tr": "Etkin"],
        "Every": [
            "ru": "Каждые", "zh": "每", "es": "Cada", "hi": "हर",
            "ar": "كل", "fr": "Toutes les", "pt": "A cada", "de": "Alle",
            "ja": "間隔", "id": "Setiap", "tr": "Her"],
        "Expires": [
            "ru": "Истекает", "zh": "到期", "es": "Vence", "hi": "समाप्ति",
            "ar": "ينتهي", "fr": "Expire", "pt": "Expira", "de": "Läuft ab",
            "ja": "有効期限", "id": "Kedaluwarsa", "tr": "Bitiş"],
        "Failed": [
            "ru": "Ошибка", "zh": "失败", "es": "Error", "hi": "विफल",
            "ar": "فشل", "fr": "Échec", "pt": "Falhou", "de": "Fehlgeschlagen",
            "ja": "失敗", "id": "Gagal", "tr": "Başarısız"],
        "From image…": [
            "ru": "Из изображения…", "zh": "从图片…", "es": "Desde imagen…", "hi": "छवि से…",
            "ar": "من صورة…", "fr": "Depuis une image…", "pt": "De uma imagem…", "de": "Aus Bild…",
            "ja": "画像から…", "id": "Dari gambar…", "tr": "Görselden…"],
        "Geo databases": [
            "ru": "Geo-базы", "zh": "Geo 数据库", "es": "Bases geo", "hi": "Geo डेटाबेस",
            "ar": "قواعد geo", "fr": "Bases geo", "pt": "Bases geo", "de": "Geo-Datenbanken",
            "ja": "geo データベース", "id": "Basis data geo", "tr": "Geo veritabanları"],
        "IPs": [
            "ru": "IP-адреса", "zh": "IP 地址", "es": "IP", "hi": "IP पते",
            "ar": "عناوين IP", "fr": "IP", "pt": "IPs", "de": "IPs",
            "ja": "IP アドレス", "id": "Alamat IP", "tr": "IP adresleri"],
        "IPv6 inside tunnel": [
            "ru": "IPv6 в туннеле", "zh": "隧道内 IPv6", "es": "IPv6 en el túnel", "hi": "टनल में IPv6",
            "ar": "IPv6 داخل النفق", "fr": "IPv6 dans le tunnel", "pt": "IPv6 no túnel", "de": "IPv6 im Tunnel",
            "ja": "トンネル内の IPv6", "id": "IPv6 dalam terowongan", "tr": "Tünel içinde IPv6"],
        "Installed": [
            "ru": "Установлен", "zh": "已安装", "es": "Instalado", "hi": "इंस्टॉल्ड",
            "ar": "مثبَّت", "fr": "Installé", "pt": "Instalado", "de": "Installiert",
            "ja": "インストール済み", "id": "Terpasang", "tr": "Yüklü"],
        "Installed.": [
            "ru": "Установлены.", "zh": "已安装。", "es": "Instaladas.", "hi": "इंस्टॉल्ड।",
            "ar": "مثبَّتة.", "fr": "Installées.", "pt": "Instaladas.", "de": "Installiert.",
            "ja": "インストール済み。", "id": "Terpasang.", "tr": "Yüklü."],
        "Name": [
            "ru": "Название", "zh": "名称", "es": "Nombre", "hi": "नाम",
            "ar": "الاسم", "fr": "Nom", "pt": "Nome", "de": "Name",
            "ja": "名前", "id": "Nama", "tr": "Ad"],
        "Network Extension (all apps)": [
            "ru": "Network Extension (все приложения)", "zh": "Network Extension（所有应用）", "es": "Network Extension (todas las apps)", "hi": "Network Extension (सभी ऐप्स)",
            "ar": "Network Extension (كل التطبيقات)", "fr": "Network Extension (toutes les apps)", "pt": "Network Extension (todos os apps)", "de": "Network Extension (alle Apps)",
            "ja": "Network Extension（全アプリ）", "id": "Network Extension (semua aplikasi)", "tr": "Network Extension (tüm uygulamalar)"],
        "New rule": [
            "ru": "Новое правило", "zh": "新规则", "es": "Nueva regla", "hi": "नया नियम",
            "ar": "قاعدة جديدة", "fr": "Nouvelle règle", "pt": "Nova regra", "de": "Neue Regel",
            "ja": "新しいルール", "id": "Aturan baru", "tr": "Yeni kural"],
        "No QR code found in that image.": [
            "ru": "В изображении нет QR-кода.", "zh": "该图片中未找到二维码。", "es": "No se encontró ningún código QR en la imagen.", "hi": "उस छवि में कोई QR कोड नहीं मिला।",
            "ar": "لم يُعثر على رمز QR في الصورة.", "fr": "Aucun QR code trouvé dans cette image.", "pt": "Nenhum QR code encontrado na imagem.", "de": "Kein QR-Code im Bild gefunden.",
            "ja": "画像に QR コードが見つかりません。", "id": "Tidak ada kode QR pada gambar itu.", "tr": "Görselde QR kod bulunamadı."],
        "No logs yet.": [
            "ru": "Логов пока нет.", "zh": "暂无日志。", "es": "Aún no hay registros.", "hi": "अभी कोई लॉग नहीं।",
            "ar": "لا توجد سجلات بعد.", "fr": "Aucun journal pour l'instant.", "pt": "Ainda não há logs.", "de": "Noch keine Logs.",
            "ja": "ログはまだありません。", "id": "Belum ada log.", "tr": "Henüz günlük yok."],
        "Not a link or subscription URL": [
            "ru": "Это не ссылка и не URL подписки", "zh": "不是链接或订阅地址", "es": "No es un enlace ni una URL de suscripción", "hi": "यह लिंक या सब्सक्रिप्शन URL नहीं है",
            "ar": "ليس رابطًا ولا عنوان اشتراك", "fr": "Ni un lien ni une URL d'abonnement", "pt": "Não é um link nem uma URL de assinatura", "de": "Weder Link noch Abo-URL",
            "ja": "リンクでもサブスクリプション URL でもありません", "id": "Bukan tautan atau URL langganan", "tr": "Bağlantı ya da abonelik adresi değil"],
        "Not installed": [
            "ru": "Не установлен", "zh": "未安装", "es": "No instalado", "hi": "इंस्टॉल नहीं है",
            "ar": "غير مثبَّت", "fr": "Non installé", "pt": "Não instalado", "de": "Nicht installiert",
            "ja": "未インストール", "id": "Belum terpasang", "tr": "Yüklü değil"],
        "Notify on connect": [
            "ru": "Уведомлять о подключении", "zh": "连接时通知", "es": "Notificar al conectar", "hi": "कनेक्ट होने पर सूचित करें",
            "ar": "تنبيه عند الاتصال", "fr": "Notifier à la connexion", "pt": "Notificar ao conectar", "de": "Bei Verbindung benachrichtigen",
            "ja": "接続時に通知", "id": "Beri tahu saat terhubung", "tr": "Bağlanınca bildir"],
        "Outbound": [
            "ru": "Исходящий", "zh": "出站", "es": "Salida", "hi": "आउटबाउंड",
            "ar": "الوجهة", "fr": "Sortie", "pt": "Saída", "de": "Ausgang",
            "ja": "アウトバウンド", "id": "Keluar", "tr": "Çıkış"],
        "Paste a link, subscription URL or config": [
            "ru": "Вставьте ссылку, URL подписки или конфиг", "zh": "粘贴链接、订阅地址或配置", "es": "Pega un enlace, URL de suscripción o configuración", "hi": "लिंक, सब्सक्रिप्शन URL या कॉन्फ़िग पेस्ट करें",
            "ar": "الصق رابطًا أو عنوان اشتراك أو إعدادًا", "fr": "Collez un lien, une URL d'abonnement ou une config", "pt": "Cole um link, URL de assinatura ou config", "de": "Link, Abo-URL oder Config einfügen",
            "ja": "リンク・サブスクリプション URL・設定を貼り付け", "id": "Tempel tautan, URL langganan, atau konfigurasi", "tr": "Bağlantı, abonelik adresi veya yapılandırma yapıştırın"],
        "Paste a server link or a subscription URL to get started.": [
            "ru": "Вставьте ссылку на сервер или URL подписки, чтобы начать.", "zh": "粘贴服务器链接或订阅地址即可开始。", "es": "Pega un enlace de servidor o una URL de suscripción para empezar.", "hi": "शुरू करने के लिए सर्वर लिंक या सब्सक्रिप्शन URL पेस्ट करें।",
            "ar": "الصق رابط خادم أو عنوان اشتراك للبدء.", "fr": "Collez un lien de serveur ou une URL d'abonnement pour commencer.", "pt": "Cole um link de servidor ou uma URL de assinatura para começar.", "de": "Server-Link oder Abo-URL einfügen, um zu starten.",
            "ja": "サーバーのリンクかサブスクリプション URL を貼り付けて始めましょう。", "id": "Tempel tautan server atau URL langganan untuk memulai.", "tr": "Başlamak için bir sunucu bağlantısı veya abonelik adresi yapıştırın."],
        "Paste from clipboard": [
            "ru": "Вставить из буфера", "zh": "从剪贴板粘贴", "es": "Pegar del portapapeles", "hi": "क्लिपबोर्ड से पेस्ट करें",
            "ar": "لصق من الحافظة", "fr": "Coller depuis le presse-papiers", "pt": "Colar da área de transferência", "de": "Aus Zwischenablage einfügen",
            "ja": "クリップボードから貼り付け", "id": "Tempel dari papan klip", "tr": "Panodan yapıştır"],
        "Port (optional)": [
            "ru": "Порт (необязательно)", "zh": "端口（可选）", "es": "Puerto (opcional)", "hi": "पोर्ट (वैकल्पिक)",
            "ar": "المنفذ (اختياري)", "fr": "Port (facultatif)", "pt": "Porta (opcional)", "de": "Port (optional)",
            "ja": "ポート（任意）", "id": "Port (opsional)", "tr": "Bağlantı noktası (isteğe bağlı)"],
        "Remove VPN profile": [
            "ru": "Удалить VPN-профиль", "zh": "删除 VPN 配置", "es": "Eliminar perfil VPN", "hi": "VPN प्रोफ़ाइल हटाएँ",
            "ar": "إزالة ملف VPN", "fr": "Supprimer le profil VPN", "pt": "Remover perfil VPN", "de": "VPN-Profil entfernen",
            "ja": "VPN プロファイルを削除", "id": "Hapus profil VPN", "tr": "VPN profilini kaldır"],
        "Remove VPN profile?": [
            "ru": "Удалить VPN-профиль?", "zh": "删除 VPN 配置？", "es": "¿Eliminar el perfil VPN?", "hi": "VPN प्रोफ़ाइल हटाएँ?",
            "ar": "إزالة ملف VPN؟", "fr": "Supprimer le profil VPN ?", "pt": "Remover perfil VPN?", "de": "VPN-Profil entfernen?",
            "ja": "VPN プロファイルを削除しますか？", "id": "Hapus profil VPN?", "tr": "VPN profili kaldırılsın mı?"],
        "Rules": [
            "ru": "Правила", "zh": "规则", "es": "Reglas", "hi": "नियम",
            "ar": "القواعد", "fr": "Règles", "pt": "Regras", "de": "Regeln",
            "ja": "ルール", "id": "Aturan", "tr": "Kurallar"],
        "Scan camera": [
            "ru": "Сканировать камерой", "zh": "用相机扫描", "es": "Escanear con la cámara", "hi": "कैमरे से स्कैन करें",
            "ar": "المسح بالكاميرا", "fr": "Scanner avec l'appareil photo", "pt": "Escanear com a câmera", "de": "Mit Kamera scannen",
            "ja": "カメラでスキャン", "id": "Pindai dengan kamera", "tr": "Kamerayla tara"],
        "Send device ID (HWID)": [
            "ru": "Отправлять ID устройства (HWID)", "zh": "发送设备 ID (HWID)", "es": "Enviar ID del dispositivo (HWID)", "hi": "डिवाइस आईडी (HWID) भेजें",
            "ar": "إرسال معرّف الجهاز (HWID)", "fr": "Envoyer l'identifiant (HWID)", "pt": "Enviar ID do dispositivo (HWID)", "de": "Geräte-ID (HWID) senden",
            "ja": "デバイス ID (HWID) を送信", "id": "Kirim ID perangkat (HWID)", "tr": "Cihaz kimliğini (HWID) gönder"],
        "Server": [
            "ru": "Сервер", "zh": "服务器", "es": "Servidor", "hi": "सर्वर",
            "ar": "الخادم", "fr": "Serveur", "pt": "Servidor", "de": "Server",
            "ja": "サーバー", "id": "Server", "tr": "Sunucu"],
        "Servers found": [
            "ru": "Найдено серверов", "zh": "找到服务器", "es": "Servidores encontrados", "hi": "सर्वर मिले",
            "ar": "الخوادم الموجودة", "fr": "Serveurs trouvés", "pt": "Servidores encontrados", "de": "Gefundene Server",
            "ja": "見つかったサーバー", "id": "Server ditemukan", "tr": "Bulunan sunucular"],
        "Share": [
            "ru": "Поделиться", "zh": "分享", "es": "Compartir", "hi": "शेयर करें",
            "ar": "مشاركة", "fr": "Partager", "pt": "Compartilhar", "de": "Teilen",
            "ja": "共有", "id": "Bagikan", "tr": "Paylaş"],
        "Show QR code": [
            "ru": "Показать QR-код", "zh": "显示二维码", "es": "Mostrar código QR", "hi": "QR कोड दिखाएँ",
            "ar": "عرض رمز QR", "fr": "Afficher le QR code", "pt": "Mostrar QR code", "de": "QR-Code anzeigen",
            "ja": "QR コードを表示", "id": "Tampilkan kode QR", "tr": "QR kodu göster"],
        "Source": [
            "ru": "Источник", "zh": "来源", "es": "Fuente", "hi": "स्रोत",
            "ar": "المصدر", "fr": "Source", "pt": "Fonte", "de": "Quelle",
            "ja": "ソース", "id": "Sumber", "tr": "Kaynak"],
        "Startup": [
            "ru": "Запуск", "zh": "启动", "es": "Inicio", "hi": "स्टार्टअप",
            "ar": "بدء التشغيل", "fr": "Démarrage", "pt": "Inicialização", "de": "Start",
            "ja": "起動", "id": "Mulai", "tr": "Başlangıç"],
        "Status": [
            "ru": "Статус", "zh": "状态", "es": "Estado", "hi": "स्थिति",
            "ar": "الحالة", "fr": "État", "pt": "Status", "de": "Status",
            "ja": "状態", "id": "Status", "tr": "Durum"],
        "The subscription returned no servers.": [
            "ru": "Подписка не вернула ни одного сервера.", "zh": "订阅未返回任何服务器。", "es": "La suscripción no devolvió servidores.", "hi": "सब्सक्रिप्शन से कोई सर्वर नहीं मिला।",
            "ar": "لم يُرجع الاشتراك أي خادم.", "fr": "L'abonnement n'a renvoyé aucun serveur.", "pt": "A assinatura não retornou servidores.", "de": "Das Abo hat keine Server geliefert.",
            "ja": "サブスクリプションからサーバーが返されませんでした。", "id": "Langganan tidak mengembalikan server.", "tr": "Abonelik hiç sunucu döndürmedi."],
        "Untitled rule": [
            "ru": "Правило без названия", "zh": "未命名规则", "es": "Regla sin nombre", "hi": "बिना नाम का नियम",
            "ar": "قاعدة بلا اسم", "fr": "Règle sans nom", "pt": "Regra sem nome", "de": "Unbenannte Regel",
            "ja": "名称未設定のルール", "id": "Aturan tanpa nama", "tr": "Adsız kural"],
        "VPN profile": [
            "ru": "VPN-профиль", "zh": "VPN 配置", "es": "Perfil VPN", "hi": "VPN प्रोफ़ाइल",
            "ar": "ملف VPN", "fr": "Profil VPN", "pt": "Perfil VPN", "de": "VPN-Profil",
            "ja": "VPN プロファイル", "id": "Profil VPN", "tr": "VPN profili"],
        "Xray core": [
            "ru": "Ядро Xray", "zh": "Xray 内核", "es": "Núcleo Xray", "hi": "Xray कोर",
            "ar": "نواة Xray", "fr": "Noyau Xray", "pt": "Núcleo Xray", "de": "Xray-Kern",
            "ja": "Xray コア", "id": "Inti Xray", "tr": "Xray çekirdeği"],
        "geosite:/geoip: rules need these files.": [
            "ru": "Правила geosite:/geoip: требуют эти файлы.", "zh": "geosite:/geoip: 规则需要这些文件。", "es": "Las reglas geosite:/geoip: necesitan estos archivos.", "hi": "geosite:/geoip: नियमों के लिए ये फ़ाइलें ज़रूरी हैं।",
            "ar": "قواعد geosite:/geoip: تحتاج هذه الملفات.", "fr": "Les règles geosite:/geoip: nécessitent ces fichiers.", "pt": "As regras geosite:/geoip: precisam destes arquivos.", "de": "geosite:/geoip:-Regeln brauchen diese Dateien.",
            "ja": "geosite:/geoip: ルールにはこれらのファイルが必要です。", "id": "Aturan geosite:/geoip: memerlukan berkas ini.", "tr": "geosite:/geoip: kuralları bu dosyaları gerektirir."],
        "iOS asks you to allow the VPN configuration the first time you connect.": [
            "ru": "При первом подключении iOS попросит разрешить VPN-конфигурацию.", "zh": "首次连接时 iOS 会请求允许该 VPN 配置。", "es": "iOS te pedirá permitir la configuración VPN la primera vez que te conectes.", "hi": "पहली बार कनेक्ट करने पर iOS VPN कॉन्फ़िगरेशन की अनुमति माँगेगा।",
            "ar": "سيطلب منك iOS السماح بإعداد VPN عند أول اتصال.", "fr": "iOS vous demandera d'autoriser la configuration VPN à la première connexion.", "pt": "O iOS pedirá para permitir a configuração VPN na primeira conexão.", "de": "iOS fragt beim ersten Verbinden nach Erlaubnis für die VPN-Konfiguration.",
            "ja": "初回接続時に iOS が VPN 構成の許可を求めます。", "id": "iOS akan meminta izin konfigurasi VPN saat pertama kali terhubung.", "tr": "iOS ilk bağlantıda VPN yapılandırmasına izin vermenizi ister."],
        "needs sing-box": [
            "ru": "нужен sing-box", "zh": "需要 sing-box", "es": "requiere sing-box", "hi": "sing-box चाहिए",
            "ar": "يتطلب sing-box", "fr": "nécessite sing-box", "pt": "requer sing-box", "de": "braucht sing-box",
            "ja": "sing-box が必要", "id": "butuh sing-box", "tr": "sing-box gerekir"],
        "not supported on iOS": [
            "ru": "не поддерживается на iOS", "zh": "在 iOS 上不支持", "es": "no compatible con iOS", "hi": "iOS पर समर्थित नहीं",
            "ar": "غير مدعوم على iOS", "fr": "non pris en charge sur iOS", "pt": "sem suporte no iOS", "de": "unter iOS nicht unterstützt",
            "ja": "iOS では非対応", "id": "tidak didukung di iOS", "tr": "iOS'ta desteklenmiyor"],
        "timeout": [
            "ru": "таймаут", "zh": "超时", "es": "tiempo agotado", "hi": "टाइमआउट",
            "ar": "انتهت المهلة", "fr": "délai dépassé", "pt": "tempo esgotado", "de": "Zeitüberschreitung",
            "ja": "タイムアウト", "id": "waktu habis", "tr": "zaman aşımı"],

        // MARK: macOS settings
        "Launch at login": [
            "ru": "Запускать при входе", "zh": "登录时启动", "es": "Abrir al iniciar sesión", "hi": "लॉगिन पर लॉन्च करें",
            "ar": "التشغيل عند تسجيل الدخول", "fr": "Lancer à l'ouverture de session", "pt": "Abrir ao iniciar sessão", "de": "Beim Anmelden starten",
            "ja": "ログイン時に起動", "id": "Jalankan saat masuk", "tr": "Oturum açınca başlat"],
        "Notify on connect / disconnect": [
            "ru": "Уведомлять о подключении / отключении", "zh": "连接/断开时通知", "es": "Notificar al conectar / desconectar", "hi": "कनेक्ट / डिस्कनेक्ट पर सूचित करें",
            "ar": "تنبيه عند الاتصال / قطع الاتصال", "fr": "Notifier à la connexion / déconnexion", "pt": "Notificar ao conectar / desconectar", "de": "Bei Verbindung / Trennung benachrichtigen",
            "ja": "接続 / 切断時に通知", "id": "Beri tahu saat terhubung / terputus", "tr": "Bağlanınca / kesilince bildir"],
        "Edit": [
            "ru": "Изменить", "zh": "编辑", "es": "Editar", "hi": "संपादित करें",
            "ar": "تحرير", "fr": "Modifier", "pt": "Editar", "de": "Bearbeiten",
            "ja": "編集", "id": "Ubah", "tr": "Düzenle"],
        "Hold to connect": [
            "ru": "Удерживайте, чтобы подключить", "zh": "长按以连接", "es": "Mantén pulsado para conectar", "hi": "कनेक्ट करने के लिए दबाए रखें",
            "ar": "اضغط مطولًا للاتصال", "fr": "Maintenez pour connecter", "pt": "Mantenha pressionado para conectar", "de": "Zum Verbinden gedrückt halten",
            "ja": "長押しで接続", "id": "Tahan untuk menghubungkan", "tr": "Bağlanmak için basılı tutun"],
        "Hold to disconnect": [
            "ru": "Удерживайте, чтобы отключить", "zh": "长按以断开", "es": "Mantén pulsado para desconectar", "hi": "डिस्कनेक्ट करने के लिए दबाए रखें",
            "ar": "اضغط مطولًا لقطع الاتصال", "fr": "Maintenez pour déconnecter", "pt": "Mantenha pressionado para desconectar", "de": "Zum Trennen gedrückt halten",
            "ja": "長押しで切断", "id": "Tahan untuk memutuskan", "tr": "Bağlantıyı kesmek için basılı tutun"],

        // MARK: Privacy / device identity
        "Regenerate": [
            "ru": "Сгенерировать заново", "zh": "重新生成", "es": "Regenerar",
            "hi": "फिर से बनाएँ", "ar": "إعادة التوليد", "fr": "Régénérer",
            "pt": "Regenerar", "de": "Neu erzeugen", "ja": "再生成",
            "id": "Buat ulang", "tr": "Yeniden oluştur"],
        "A new ID looks like a new device to your provider and may use up a device slot.": [
            "ru": "Новый ID выглядит для провайдера как новое устройство и может занять слот.",
            "zh": "新的 ID 在提供商看来是一台新设备，可能会占用一个设备名额。",
            "es": "Un ID nuevo parece un dispositivo nuevo para tu proveedor y puede ocupar una plaza.",
            "hi": "नया ID आपके प्रोवाइडर को नया डिवाइस लगता है और एक डिवाइस स्लॉट ले सकता है।",
            "ar": "المعرّف الجديد يبدو لمزوّدك كجهاز جديد وقد يستهلك خانة جهاز.",
            "fr": "Un nouvel ID apparaît comme un nouvel appareil pour votre fournisseur et peut consommer un emplacement.",
            "pt": "Um ID novo parece um dispositivo novo para o seu provedor e pode ocupar uma vaga.",
            "de": "Eine neue ID wirkt für deinen Anbieter wie ein neues Gerät und kann einen Geräteplatz belegen.",
            "ja": "新しい ID はプロバイダーには新しい端末として見えるため、端末枠を消費することがあります。",
            "id": "ID baru terlihat seperti perangkat baru bagi penyedia dan bisa memakai satu slot perangkat.",
            "tr": "Yeni bir kimlik, sağlayıcınıza yeni bir cihaz gibi görünür ve bir cihaz hakkını kullanabilir."],
        "User-Agent (optional)": [
            "ru": "User-Agent (необязательно)", "zh": "User-Agent（可选）",
            "es": "User-Agent (opcional)", "hi": "User-Agent (वैकल्पिक)",
            "ar": "User-Agent (اختياري)", "fr": "User-Agent (facultatif)",
            "pt": "User-Agent (opcional)", "de": "User-Agent (optional)",
            "ja": "User-Agent（任意）", "id": "User-Agent (opsional)",
            "tr": "User-Agent (isteğe bağlı)"],
        "Leave empty unless your provider's rules expect a particular client.": [
            "ru": "Оставьте пустым, если правила провайдера не ждут конкретный клиент.",
            "zh": "除非提供商的规则需要特定客户端，否则请留空。",
            "es": "Déjalo vacío salvo que las reglas de tu proveedor esperen un cliente concreto.",
            "hi": "खाली छोड़ें, जब तक आपके प्रोवाइडर के नियम किसी खास क्लाइंट की अपेक्षा न करें।",
            "ar": "اتركه فارغًا ما لم تكن قواعد مزوّدك تتوقع عميلًا معيّنًا.",
            "fr": "Laissez vide, sauf si les règles de votre fournisseur attendent un client précis.",
            "pt": "Deixe vazio, a menos que as regras do seu provedor esperem um cliente específico.",
            "de": "Leer lassen, sofern die Regeln deines Anbieters keinen bestimmten Client erwarten.",
            "ja": "プロバイダーのルールが特定のクライアントを求めていない限り、空のままにしてください。",
            "id": "Biarkan kosong kecuali aturan penyedia Anda mengharapkan klien tertentu.",
            "tr": "Sağlayıcınızın kuralları belirli bir istemci beklemiyorsa boş bırakın."],
        "Privacy": [
            "ru": "Приватность", "zh": "隐私", "es": "Privacidad", "hi": "गोपनीयता",
            "ar": "الخصوصية", "fr": "Confidentialité", "pt": "Privacidade",
            "de": "Datenschutz", "ja": "プライバシー", "id": "Privasi", "tr": "Gizlilik"],
        "Export diagnostics": [
            "ru": "Экспорт диагностики", "zh": "导出诊断信息",
            "es": "Exportar diagnóstico", "hi": "डायग्नोस्टिक्स निर्यात करें",
            "ar": "تصدير التشخيص", "fr": "Exporter le diagnostic",
            "pt": "Exportar diagnóstico", "de": "Diagnose exportieren",
            "ja": "診断情報を書き出す", "id": "Ekspor diagnostik",
            "tr": "Tanılamayı dışa aktar"],
        "Copies a report with subscription URLs, tokens and IDs removed.": [
            "ru": "Копирует отчёт без URL подписок, токенов и идентификаторов.",
            "zh": "复制的报告已移除订阅链接、令牌和标识符。",
            "es": "Copia un informe sin URLs de suscripción, tokens ni identificadores.",
            "hi": "रिपोर्ट कॉपी करता है जिसमें सब्सक्रिप्शन URL, टोकन और ID हटा दिए गए हों।",
            "ar": "ينسخ تقريرًا بعد إزالة روابط الاشتراك والرموز والمعرّفات.",
            "fr": "Copie un rapport sans URL d'abonnement, jetons ni identifiants.",
            "pt": "Copia um relatório sem URLs de assinatura, tokens e identificadores.",
            "de": "Kopiert einen Bericht ohne Abo-URLs, Token und Kennungen.",
            "ja": "購読 URL・トークン・識別子を取り除いたレポートをコピーします。",
            "id": "Menyalin laporan tanpa URL langganan, token, dan pengenal.",
            "tr": "Abonelik adresleri, belirteçler ve kimlikler çıkarılmış bir rapor kopyalar."],
        "Copy": [
            "ru": "Копировать", "zh": "复制", "es": "Copiar", "hi": "कॉपी करें",
            "ar": "نسخ", "fr": "Copier", "pt": "Copiar", "de": "Kopieren",
            "ja": "コピー", "id": "Salin", "tr": "Kopyala"],
        "Copied": [
            "ru": "Скопировано", "zh": "已复制", "es": "Copiado", "hi": "कॉपी हो गया",
            "ar": "تم النسخ", "fr": "Copié", "pt": "Copiado", "de": "Kopiert",
            "ja": "コピーしました", "id": "Disalin", "tr": "Kopyalandı"],


        // MARK: Routing — rules editor
        "Apps": [
            "ru": "Приложения", "zh": "应用", "es": "Apps", "hi": "ऐप्स",
            "ar": "التطبيقات", "fr": "Applications", "pt": "Apps", "de": "Apps",
            "ja": "アプリ", "id": "Aplikasi", "tr": "Uygulamalar"],
        "Choose…": [
            "ru": "Выбрать…", "zh": "选择…", "es": "Elegir…", "hi": "चुनें…",
            "ar": "اختيار…", "fr": "Choisir…", "pt": "Escolher…", "de": "Auswählen…",
            "ja": "選択…", "id": "Pilih…", "tr": "Seç…"],
        "Choose applications": [
            "ru": "Выбор приложений", "zh": "选择应用", "es": "Elegir aplicaciones",
            "hi": "एप्लिकेशन चुनें", "ar": "اختيار التطبيقات", "fr": "Choisir des applications",
            "pt": "Escolher aplicativos", "de": "Programme auswählen",
            "ja": "アプリを選択", "id": "Pilih aplikasi", "tr": "Uygulama seç"],
        "Search by name, executable or bundle id": [
            "ru": "Поиск по названию, исполняемому файлу или bundle id",
            "zh": "按名称、可执行文件或 bundle id 搜索",
            "es": "Buscar por nombre, ejecutable o bundle id",
            "hi": "नाम, executable या bundle id से खोजें",
            "ar": "البحث بالاسم أو الملف التنفيذي أو bundle id",
            "fr": "Rechercher par nom, exécutable ou bundle id",
            "pt": "Buscar por nome, executável ou bundle id",
            "de": "Nach Name, Programmdatei oder Bundle-ID suchen",
            "ja": "名前・実行ファイル・bundle id で検索",
            "id": "Cari berdasarkan nama, executable, atau bundle id",
            "tr": "Ada, çalıştırılabilir dosyaya veya bundle id'ye göre ara"],
        "Running": [
            "ru": "Запущенные", "zh": "运行中", "es": "En ejecución", "hi": "चल रहे",
            "ar": "قيد التشغيل", "fr": "En cours", "pt": "Em execução", "de": "Laufend",
            "ja": "実行中", "id": "Berjalan", "tr": "Çalışan"],
        "Nothing selected": [
            "ru": "Ничего не выбрано", "zh": "未选择", "es": "Nada seleccionado",
            "hi": "कुछ नहीं चुना गया", "ar": "لم يتم اختيار شيء", "fr": "Rien de sélectionné",
            "pt": "Nada selecionado", "de": "Nichts ausgewählt",
            "ja": "未選択", "id": "Tidak ada yang dipilih", "tr": "Hiçbir şey seçilmedi"],
        "selected": [
            "ru": "выбрано", "zh": "已选择", "es": "seleccionados", "hi": "चयनित",
            "ar": "محدد", "fr": "sélectionnés", "pt": "selecionados", "de": "ausgewählt",
            "ja": "件を選択", "id": "dipilih", "tr": "seçildi"],
        "Executable name": [
            "ru": "Имя исполняемого файла", "zh": "可执行文件名", "es": "Nombre del ejecutable",
            "hi": "Executable का नाम", "ar": "اسم الملف التنفيذي", "fr": "Nom de l'exécutable",
            "pt": "Nome do executável", "de": "Name der Programmdatei",
            "ja": "実行ファイル名", "id": "Nama executable", "tr": "Çalıştırılabilir dosya adı"],
        "Executable paths": [
            "ru": "Пути к исполняемым файлам", "zh": "可执行文件路径",
            "es": "Rutas de ejecutables", "hi": "Executable पाथ",
            "ar": "مسارات الملفات التنفيذية", "fr": "Chemins des exécutables",
            "pt": "Caminhos dos executáveis", "de": "Pfade der Programmdateien",
            "ja": "実行ファイルのパス", "id": "Jalur executable", "tr": "Çalıştırılabilir dosya yolları"],
        "More": [
            "ru": "Ещё", "zh": "更多", "es": "Más", "hi": "और",
            "ar": "المزيد", "fr": "Plus", "pt": "Mais", "de": "Mehr",
            "ja": "詳細", "id": "Lainnya", "tr": "Daha fazla"],
        "Network": [
            "ru": "Сеть", "zh": "网络", "es": "Red", "hi": "नेटवर्क",
            "ar": "الشبكة", "fr": "Réseau", "pt": "Rede", "de": "Netzwerk",
            "ja": "ネットワーク", "id": "Jaringan", "tr": "Ağ"],
        "Any": [
            "ru": "Любая", "zh": "任意", "es": "Cualquiera", "hi": "कोई भी",
            "ar": "أي", "fr": "Tous", "pt": "Qualquer", "de": "Beliebig",
            "ja": "すべて", "id": "Apa saja", "tr": "Herhangi"],
        "Addresses are": [
            "ru": "Адреса — это", "zh": "地址属于", "es": "Las direcciones son",
            "hi": "पते हैं", "ar": "العناوين هي", "fr": "Les adresses sont",
            "pt": "Os endereços são", "de": "Adressen sind",
            "ja": "アドレスの種別", "id": "Alamat adalah", "tr": "Adresler"],
        "Invert": [
            "ru": "Инвертировать", "zh": "反转", "es": "Invertir", "hi": "उलटें",
            "ar": "عكس", "fr": "Inverser", "pt": "Inverter", "de": "Umkehren",
            "ja": "反転", "id": "Balikkan", "tr": "Tersine çevir"],
        "Protocols (sniffed)": [
            "ru": "Протоколы (по анализу трафика)", "zh": "协议（嗅探）",
            "es": "Protocolos (detectados)", "hi": "प्रोटोकॉल (sniff किए गए)",
            "ar": "البروتوكولات (مكتشفة)", "fr": "Protocoles (détectés)",
            "pt": "Protocolos (detectados)", "de": "Protokolle (erkannt)",
            "ja": "プロトコル（スニフ）", "id": "Protokol (hasil sniff)",
            "tr": "Protokoller (tespit edilen)"],
        "From template": [
            "ru": "Из шаблона", "zh": "使用模板", "es": "Desde plantilla",
            "hi": "टेम्पलेट से", "ar": "من قالب", "fr": "Depuis un modèle",
            "pt": "A partir de modelo", "de": "Aus Vorlage",
            "ja": "テンプレートから", "id": "Dari templat", "tr": "Şablondan"],
        "No rules yet.": [
            "ru": "Правил пока нет.", "zh": "还没有规则。", "es": "Aún no hay reglas.",
            "hi": "अभी कोई नियम नहीं।", "ar": "لا توجد قواعد بعد.", "fr": "Aucune règle pour l'instant.",
            "pt": "Ainda não há regras.", "de": "Noch keine Regeln.",
            "ja": "ルールはまだありません。", "id": "Belum ada aturan.", "tr": "Henüz kural yok."],
        "Add one to send an application, a domain or a network through a particular server.": [
            "ru": "Добавьте правило, чтобы направить приложение, домен или сеть через конкретный сервер.",
            "zh": "添加规则，把某个应用、域名或网段发往指定服务器。",
            "es": "Añade una para enviar una aplicación, un dominio o una red por un servidor concreto.",
            "hi": "किसी ऐप, डोमेन या नेटवर्क को किसी खास सर्वर से भेजने के लिए नियम जोड़ें।",
            "ar": "أضف قاعدة لتوجيه تطبيق أو نطاق أو شبكة عبر خادم محدد.",
            "fr": "Ajoutez-en une pour envoyer une application, un domaine ou un réseau via un serveur précis.",
            "pt": "Adicione uma para enviar um aplicativo, domínio ou rede por um servidor específico.",
            "de": "Füge eine hinzu, um ein Programm, eine Domain oder ein Netz über einen bestimmten Server zu leiten.",
            "ja": "特定のサーバーへアプリ・ドメイン・ネットワークを送るルールを追加します。",
            "id": "Tambahkan satu untuk mengirim aplikasi, domain, atau jaringan lewat server tertentu.",
            "tr": "Bir uygulamayı, alan adını ya da ağı belirli bir sunucudan geçirmek için kural ekleyin."],
        "Application rules need TUN mode with the native core enabled in Settings.": [
            "ru": "Правила по приложениям работают в режиме TUN с нативным ядром, включённым в настройках.",
            "zh": "应用规则需要在设置中启用原生内核的 TUN 模式。",
            "es": "Las reglas por aplicación requieren el modo TUN con el núcleo nativo activado en Ajustes.",
            "hi": "ऐप नियमों के लिए Settings में native core वाला TUN मोड चाहिए।",
            "ar": "قواعد التطبيقات تتطلب وضع TUN مع تفعيل النواة الأصلية في الإعدادات.",
            "fr": "Les règles par application nécessitent le mode TUN avec le cœur natif activé dans les réglages.",
            "pt": "Regras por aplicativo exigem o modo TUN com o núcleo nativo ativado nas Configurações.",
            "de": "Programmregeln brauchen den TUN-Modus mit dem nativen Kern, aktiviert in den Einstellungen.",
            "ja": "アプリ単位のルールには、設定でネイティブコアを有効にした TUN モードが必要です。",
            "id": "Aturan aplikasi memerlukan mode TUN dengan core native yang diaktifkan di Pengaturan.",
            "tr": "Uygulama kuralları, Ayarlar'da yerel çekirdek açıkken TUN modunu gerektirir."],
        "Application matching is enforced by the sing-box core in TUN mode. The Xray path skips these rules rather than widening them.": [
            "ru": "Совпадение по приложению обеспечивает ядро sing-box в режиме TUN. Ядро Xray пропускает такие правила, а не расширяет их.",
            "zh": "应用匹配由 TUN 模式下的 sing-box 内核完成。Xray 路径会跳过这类规则，而不是放宽它们。",
            "es": "La coincidencia por aplicación la aplica el núcleo sing-box en modo TUN. La vía Xray omite estas reglas en lugar de ampliarlas.",
            "hi": "ऐप मिलान TUN मोड में sing-box core करता है। Xray पथ ऐसे नियमों को चौड़ा करने के बजाय छोड़ देता है।",
            "ar": "مطابقة التطبيقات تنفّذها نواة sing-box في وضع TUN. مسار Xray يتخطى هذه القواعد بدل توسيعها.",
            "fr": "La correspondance par application est assurée par le cœur sing-box en mode TUN. La voie Xray ignore ces règles au lieu de les élargir.",
            "pt": "A correspondência por aplicativo é feita pelo núcleo sing-box no modo TUN. O caminho Xray ignora essas regras em vez de ampliá-las.",
            "de": "Programm-Treffer setzt der sing-box-Kern im TUN-Modus durch. Der Xray-Weg überspringt solche Regeln, statt sie auszuweiten.",
            "ja": "アプリの一致は TUN モードの sing-box コアが処理します。Xray 経路はこうしたルールを広げず、そのまま飛ばします。",
            "id": "Pencocokan aplikasi dijalankan core sing-box dalam mode TUN. Jalur Xray melewati aturan ini alih-alih memperlebarnya.",
            "tr": "Uygulama eşleşmesini TUN modunda sing-box çekirdeği uygular. Xray yolu bu kuralları genişletmek yerine atlar."],
        "Rules — top to bottom, first match wins": [
            "ru": "Правила — сверху вниз, срабатывает первое совпадение",
            "zh": "规则 — 自上而下，先匹配先生效",
            "es": "Reglas: de arriba abajo, gana la primera coincidencia",
            "hi": "नियम — ऊपर से नीचे, पहला मिलान लागू",
            "ar": "القواعد — من الأعلى للأسفل، أول تطابق يفوز",
            "fr": "Règles — de haut en bas, la première correspondance gagne",
            "pt": "Regras — de cima para baixo, vence a primeira correspondência",
            "de": "Regeln — von oben nach unten, der erste Treffer gewinnt",
            "ja": "ルール — 上から下へ、最初に一致したものが有効",
            "id": "Aturan — dari atas ke bawah, kecocokan pertama menang",
            "tr": "Kurallar — yukarıdan aşağıya, ilk eşleşme geçerli"],
        "A rule matches when every filled-in field matches. Domains: example.com, domain:example.com, keyword:google, geosite:netflix. IPs: 1.2.3.0/24, geoip:cn.": [
            "ru": "Правило срабатывает, когда совпали все заполненные поля. Домены: example.com, domain:example.com, keyword:google, geosite:netflix. IP: 1.2.3.0/24, geoip:cn.",
            "zh": "所有已填字段都匹配时规则才生效。域名：example.com、domain:example.com、keyword:google、geosite:netflix。IP：1.2.3.0/24、geoip:cn。",
            "es": "Una regla coincide cuando coinciden todos los campos rellenados. Dominios: example.com, domain:example.com, keyword:google, geosite:netflix. IP: 1.2.3.0/24, geoip:cn.",
            "hi": "नियम तभी लागू होता है जब सभी भरे हुए फ़ील्ड मेल खाएँ। डोमेन: example.com, domain:example.com, keyword:google, geosite:netflix। IP: 1.2.3.0/24, geoip:cn।",
            "ar": "تتطابق القاعدة عندما تتطابق كل الحقول المعبأة. النطاقات: example.com وdomain:example.com وkeyword:google وgeosite:netflix. عناوين IP: 1.2.3.0/24 وgeoip:cn.",
            "fr": "Une règle correspond quand tous les champs remplis correspondent. Domaines : example.com, domain:example.com, keyword:google, geosite:netflix. IP : 1.2.3.0/24, geoip:cn.",
            "pt": "Uma regra corresponde quando todos os campos preenchidos correspondem. Domínios: example.com, domain:example.com, keyword:google, geosite:netflix. IPs: 1.2.3.0/24, geoip:cn.",
            "de": "Eine Regel trifft zu, wenn alle ausgefüllten Felder zutreffen. Domains: example.com, domain:example.com, keyword:google, geosite:netflix. IPs: 1.2.3.0/24, geoip:cn.",
            "ja": "入力したすべての条件が一致したときにルールが適用されます。ドメイン: example.com、domain:example.com、keyword:google、geosite:netflix。IP: 1.2.3.0/24、geoip:cn。",
            "id": "Aturan cocok bila semua kolom yang diisi cocok. Domain: example.com, domain:example.com, keyword:google, geosite:netflix. IP: 1.2.3.0/24, geoip:cn.",
            "tr": "Doldurulan tüm alanlar eşleştiğinde kural uygulanır. Alan adları: example.com, domain:example.com, keyword:google, geosite:netflix. IP: 1.2.3.0/24, geoip:cn."],
        "Your own rules below run under every preset, after the LAN bypass and before the preset's country rules.": [
            "ru": "Ваши правила ниже действуют при любом пресете: после обхода локальной сети и до страновых правил пресета.",
            "zh": "下面你自己的规则在任何预设下都会生效：排在局域网直连之后、预设的国家规则之前。",
            "es": "Tus reglas de abajo se aplican con cualquier preajuste: después del bypass de la LAN y antes de las reglas de país del preajuste.",
            "hi": "नीचे दिए आपके नियम हर प्रीसेट में चलते हैं — LAN bypass के बाद और प्रीसेट के देश-नियमों से पहले।",
            "ar": "قواعدك أدناه تعمل مع كل الإعدادات المسبقة: بعد تجاوز الشبكة المحلية وقبل قواعد الدول في الإعداد المسبق.",
            "fr": "Vos règles ci-dessous s'appliquent avec tous les préréglages : après le contournement du LAN et avant les règles pays du préréglage.",
            "pt": "Suas regras abaixo valem em todos os predefinidos: depois do bypass da LAN e antes das regras de país do predefinido.",
            "de": "Deine Regeln unten gelten bei jeder Voreinstellung: nach dem LAN-Bypass und vor den Länderregeln der Voreinstellung.",
            "ja": "下のユーザールールはどのプリセットでも有効です。LAN 直結の後、プリセットの国別ルールの前に評価されます。",
            "id": "Aturan Anda di bawah berlaku di semua preset: setelah bypass LAN dan sebelum aturan negara dari preset.",
            "tr": "Aşağıdaki kendi kurallarınız her ön ayarda çalışır: LAN atlamasından sonra, ön ayarın ülke kurallarından önce."],
        "Changes apply on the next connect or reconnect.": [
            "ru": "Изменения применятся при следующем подключении или переподключении.",
            "zh": "更改将在下次连接或重连时生效。",
            "es": "Los cambios se aplican en la próxima conexión o reconexión.",
            "hi": "बदलाव अगली बार कनेक्ट या रीकनेक्ट करने पर लागू होंगे।",
            "ar": "تُطبَّق التغييرات عند الاتصال أو إعادة الاتصال التالي.",
            "fr": "Les modifications s'appliquent à la prochaine connexion ou reconnexion.",
            "pt": "As alterações entram em vigor na próxima conexão ou reconexão.",
            "de": "Änderungen wirken beim nächsten Verbinden oder Neuverbinden.",
            "ja": "変更は次回の接続または再接続で反映されます。",
            "id": "Perubahan berlaku pada koneksi atau sambungan ulang berikutnya.",
            "tr": "Değişiklikler bir sonraki bağlanmada veya yeniden bağlanmada geçerli olur."],
        "Used by the Xray core. The sing-box core downloads the matching rule-sets on its own.": [
            "ru": "Используется ядром Xray. Ядро sing-box само скачивает соответствующие rule-set.",
            "zh": "供 Xray 内核使用。sing-box 内核会自行下载对应的 rule-set。",
            "es": "Lo usa el núcleo Xray. El núcleo sing-box descarga por su cuenta los rule-sets correspondientes.",
            "hi": "Xray core इसे उपयोग करता है। sing-box core संबंधित rule-set खुद डाउनलोड करता है।",
            "ar": "تستخدمها نواة Xray. أما نواة sing-box فتنزّل مجموعات القواعد المقابلة بنفسها.",
            "fr": "Utilisé par le cœur Xray. Le cœur sing-box télécharge lui-même les rule-sets correspondants.",
            "pt": "Usado pelo núcleo Xray. O núcleo sing-box baixa sozinho os rule-sets correspondentes.",
            "de": "Wird vom Xray-Kern genutzt. Der sing-box-Kern lädt die passenden Rule-Sets selbst.",
            "ja": "Xray コアが使用します。sing-box コアは対応する rule-set を自分でダウンロードします。",
            "id": "Dipakai core Xray. Core sing-box mengunduh rule-set yang sesuai sendiri.",
            "tr": "Xray çekirdeği kullanır. sing-box çekirdeği ilgili rule-set'leri kendisi indirir."],

        // MARK: Routing — groups
        "Groups": [
            "ru": "Группы", "zh": "分组", "es": "Grupos", "hi": "समूह",
            "ar": "المجموعات", "fr": "Groupes", "pt": "Grupos", "de": "Gruppen",
            "ja": "グループ", "id": "Grup", "tr": "Gruplar"],
        "Group": [
            "ru": "Группа", "zh": "分组", "es": "Grupo", "hi": "समूह",
            "ar": "مجموعة", "fr": "Groupe", "pt": "Grupo", "de": "Gruppe",
            "ja": "グループ", "id": "Grup", "tr": "Grup"],
        "Group name": [
            "ru": "Название группы", "zh": "分组名称", "es": "Nombre del grupo",
            "hi": "समूह का नाम", "ar": "اسم المجموعة", "fr": "Nom du groupe",
            "pt": "Nome do grupo", "de": "Gruppenname",
            "ja": "グループ名", "id": "Nama grup", "tr": "Grup adı"],
        "Add group": [
            "ru": "Добавить группу", "zh": "添加分组", "es": "Añadir grupo",
            "hi": "समूह जोड़ें", "ar": "إضافة مجموعة", "fr": "Ajouter un groupe",
            "pt": "Adicionar grupo", "de": "Gruppe hinzufügen",
            "ja": "グループを追加", "id": "Tambah grup", "tr": "Grup ekle"],
        "No groups yet.": [
            "ru": "Групп пока нет.", "zh": "还没有分组。", "es": "Aún no hay grupos.",
            "hi": "अभी कोई समूह नहीं।", "ar": "لا توجد مجموعات بعد.", "fr": "Aucun groupe pour l'instant.",
            "pt": "Ainda não há grupos.", "de": "Noch keine Gruppen.",
            "ja": "グループはまだありません。", "id": "Belum ada grup.", "tr": "Henüz grup yok."],
        "A group behaves like one server: pick a member by hand, or let the fastest one win.": [
            "ru": "Группа ведёт себя как один сервер: выберите участника вручную или пусть победит самый быстрый.",
            "zh": "分组的行为就像一个服务器：手动选择成员，或让最快的胜出。",
            "es": "Un grupo se comporta como un servidor: elige un miembro a mano o deja que gane el más rápido.",
            "hi": "समूह एक सर्वर की तरह काम करता है: सदस्य खुद चुनें या सबसे तेज़ को जीतने दें।",
            "ar": "تتصرف المجموعة كخادم واحد: اختر عضوًا يدويًا أو دع الأسرع يفوز.",
            "fr": "Un groupe se comporte comme un seul serveur : choisissez un membre à la main ou laissez le plus rapide gagner.",
            "pt": "Um grupo funciona como um servidor: escolha um membro à mão ou deixe o mais rápido vencer.",
            "de": "Eine Gruppe verhält sich wie ein Server: Mitglied selbst wählen oder das schnellste gewinnen lassen.",
            "ja": "グループは 1 台のサーバーのように動きます。メンバーを手で選ぶか、最速のものに任せます。",
            "id": "Grup berperilaku seperti satu server: pilih anggota secara manual, atau biarkan yang tercepat menang.",
            "tr": "Grup tek bir sunucu gibi davranır: üyeyi elle seçin ya da en hızlısı kazansın."],
        "Groups also show up in the control API, so a dashboard — or an assistant — can switch the member without restarting the tunnel.": [
            "ru": "Группы видны и в control API, поэтому панель — или ассистент — может сменить участника без перезапуска туннеля.",
            "zh": "分组也会出现在控制 API 中，面板或助手可以在不重启隧道的情况下切换成员。",
            "es": "Los grupos también aparecen en la API de control, así que un panel —o un asistente— puede cambiar de miembro sin reiniciar el túnel.",
            "hi": "समूह control API में भी दिखते हैं, इसलिए डैशबोर्ड — या कोई असिस्टेंट — टनल रीस्टार्ट किए बिना सदस्य बदल सकता है।",
            "ar": "تظهر المجموعات أيضًا في واجهة التحكم، فيمكن للوحة — أو لمساعد — تبديل العضو دون إعادة تشغيل النفق.",
            "fr": "Les groupes apparaissent aussi dans l'API de contrôle : un tableau de bord — ou un assistant — peut changer de membre sans redémarrer le tunnel.",
            "pt": "Os grupos também aparecem na API de controle, então um painel — ou um assistente — pode trocar o membro sem reiniciar o túnel.",
            "de": "Gruppen erscheinen auch in der Steuerungs-API, sodass ein Dashboard — oder ein Assistent — das Mitglied ohne Neustart des Tunnels wechseln kann.",
            "ja": "グループは制御 API にも現れるため、ダッシュボードやアシスタントがトンネルを再起動せずにメンバーを切り替えられます。",
            "id": "Grup juga muncul di control API, sehingga dasbor — atau asisten — bisa mengganti anggota tanpa memulai ulang terowongan.",
            "tr": "Gruplar kontrol API'sinde de görünür; bir panel — ya da bir asistan — tüneli yeniden başlatmadan üyeyi değiştirebilir."],
        "Picks": [
            "ru": "Выбор", "zh": "选择方式", "es": "Selección", "hi": "चयन",
            "ar": "الاختيار", "fr": "Sélection", "pt": "Seleção", "de": "Auswahl",
            "ja": "選び方", "id": "Pemilihan", "tr": "Seçim"],
        "Members": [
            "ru": "Участники", "zh": "成员", "es": "Miembros", "hi": "सदस्य",
            "ar": "الأعضاء", "fr": "Membres", "pt": "Membros", "de": "Mitglieder",
            "ja": "メンバー", "id": "Anggota", "tr": "Üyeler"],
        "Add a server first.": [
            "ru": "Сначала добавьте сервер.", "zh": "请先添加服务器。",
            "es": "Primero añade un servidor.", "hi": "पहले एक सर्वर जोड़ें।",
            "ar": "أضف خادمًا أولًا.", "fr": "Ajoutez d'abord un serveur.",
            "pt": "Adicione um servidor primeiro.", "de": "Zuerst einen Server hinzufügen.",
            "ja": "先にサーバーを追加してください。", "id": "Tambahkan server dulu.",
            "tr": "Önce bir sunucu ekleyin."],
        "Use this member": [
            "ru": "Использовать этого участника", "zh": "使用该成员",
            "es": "Usar este miembro", "hi": "इस सदस्य का उपयोग करें",
            "ar": "استخدام هذا العضو", "fr": "Utiliser ce membre",
            "pt": "Usar este membro", "de": "Dieses Mitglied verwenden",
            "ja": "このメンバーを使う", "id": "Gunakan anggota ini", "tr": "Bu üyeyi kullan"],
        "Test URL": [
            "ru": "URL для проверки", "zh": "测试 URL", "es": "URL de prueba",
            "hi": "टेस्ट URL", "ar": "رابط الاختبار", "fr": "URL de test",
            "pt": "URL de teste", "de": "Test-URL",
            "ja": "テスト URL", "id": "URL uji", "tr": "Test adresi"],
        "Tolerance, ms": [
            "ru": "Допуск, мс", "zh": "容差（毫秒）", "es": "Tolerancia, ms",
            "hi": "सहनशीलता, ms", "ar": "التفاوت، مللي ثانية", "fr": "Tolérance, ms",
            "pt": "Tolerância, ms", "de": "Toleranz, ms",
            "ja": "許容差 (ms)", "id": "Toleransi, ms", "tr": "Tolerans, ms"],

        // MARK: Routing — DNS
        "Resolver": [
            "ru": "Резолвер", "zh": "解析器", "es": "Resolutor", "hi": "रिज़ॉल्वर",
            "ar": "محلّل الأسماء", "fr": "Résolveur", "pt": "Resolvedor", "de": "Resolver",
            "ja": "リゾルバ", "id": "Resolver", "tr": "Çözücü"],
        "Servers": [
            "ru": "Серверы", "zh": "服务器", "es": "Servidores", "hi": "सर्वर",
            "ar": "الخوادم", "fr": "Serveurs", "pt": "Servidores", "de": "Server",
            "ja": "サーバー", "id": "Server", "tr": "Sunucular"],
        "Handle DNS in the tunnel": [
            "ru": "Обрабатывать DNS в туннеле", "zh": "在隧道内处理 DNS",
            "es": "Gestionar el DNS en el túnel", "hi": "DNS को टनल में संभालें",
            "ar": "معالجة DNS داخل النفق", "fr": "Gérer le DNS dans le tunnel",
            "pt": "Tratar o DNS no túnel", "de": "DNS im Tunnel auflösen",
            "ja": "DNS をトンネル内で処理", "id": "Tangani DNS di dalam terowongan",
            "tr": "DNS'i tünel içinde çöz"],
        "Answer with": [
            "ru": "Отвечать через", "zh": "默认使用", "es": "Responder con",
            "hi": "इससे उत्तर दें", "ar": "الرد عبر", "fr": "Répondre avec",
            "pt": "Responder com", "de": "Antworten über",
            "ja": "既定の応答元", "id": "Jawab dengan", "tr": "Şununla yanıtla"],
        "Address family": [
            "ru": "Тип адресов", "zh": "地址族", "es": "Familia de direcciones",
            "hi": "एड्रेस फ़ैमिली", "ar": "عائلة العناوين", "fr": "Famille d'adresses",
            "pt": "Família de endereços", "de": "Adressfamilie",
            "ja": "アドレスファミリ", "id": "Keluarga alamat", "tr": "Adres ailesi"],
        "Prefer IPv4": [
            "ru": "Предпочитать IPv4", "zh": "优先 IPv4", "es": "Preferir IPv4",
            "hi": "IPv4 को प्राथमिकता", "ar": "تفضيل IPv4", "fr": "Préférer IPv4",
            "pt": "Preferir IPv4", "de": "IPv4 bevorzugen",
            "ja": "IPv4 を優先", "id": "Utamakan IPv4", "tr": "IPv4 tercih et"],
        "Prefer IPv6": [
            "ru": "Предпочитать IPv6", "zh": "优先 IPv6", "es": "Preferir IPv6",
            "hi": "IPv6 को प्राथमिकता", "ar": "تفضيل IPv6", "fr": "Préférer IPv6",
            "pt": "Preferir IPv6", "de": "IPv6 bevorzugen",
            "ja": "IPv6 を優先", "id": "Utamakan IPv6", "tr": "IPv6 tercih et"],
        "IPv4 only": [
            "ru": "Только IPv4", "zh": "仅 IPv4", "es": "Solo IPv4", "hi": "केवल IPv4",
            "ar": "IPv4 فقط", "fr": "IPv4 uniquement", "pt": "Somente IPv4", "de": "Nur IPv4",
            "ja": "IPv4 のみ", "id": "Hanya IPv4", "tr": "Yalnızca IPv4"],
        "IPv6 only": [
            "ru": "Только IPv6", "zh": "仅 IPv6", "es": "Solo IPv6", "hi": "केवल IPv6",
            "ar": "IPv6 فقط", "fr": "IPv6 uniquement", "pt": "Somente IPv6", "de": "Nur IPv6",
            "ja": "IPv6 のみ", "id": "Hanya IPv6", "tr": "Yalnızca IPv6"],
        "Serve stale answers while refreshing": [
            "ru": "Отдавать устаревший ответ, пока обновляется",
            "zh": "刷新期间先返回旧记录",
            "es": "Servir respuestas caducadas mientras se actualizan",
            "hi": "रिफ़्रेश के दौरान पुराना उत्तर दें",
            "ar": "تقديم إجابة قديمة أثناء التحديث",
            "fr": "Servir les réponses périmées pendant l'actualisation",
            "pt": "Servir respostas antigas enquanto atualiza",
            "de": "Veraltete Antworten während der Aktualisierung liefern",
            "ja": "更新中は古い応答を返す",
            "id": "Sajikan jawaban lama selagi menyegarkan",
            "tr": "Yenilenirken eski yanıtı ver"],
        "FakeIP": [
            "ru": "FakeIP", "zh": "FakeIP", "es": "FakeIP", "hi": "FakeIP",
            "ar": "FakeIP", "fr": "FakeIP", "pt": "FakeIP", "de": "FakeIP",
            "ja": "FakeIP", "id": "FakeIP", "tr": "FakeIP"],
        "Answers instantly from a private range and keeps the domain visible to rules. Breaks software that resolves names itself.": [
            "ru": "Мгновенно отвечает адресом из приватного диапазона и сохраняет домен видимым для правил. Ломает программы, которые резолвят имена сами.",
            "zh": "用私有网段立即作答，并让规则仍能看到域名。会破坏自行解析域名的软件。",
            "es": "Responde al instante con un rango privado y mantiene el dominio visible para las reglas. Rompe el software que resuelve los nombres por su cuenta.",
            "hi": "प्राइवेट रेंज से तुरंत उत्तर देता है और डोमेन नियमों को दिखता रहता है। जो सॉफ़्टवेयर खुद नाम रिज़ॉल्व करते हैं, वे टूट जाते हैं।",
            "ar": "يرد فورًا من نطاق خاص ويبقي اسم النطاق ظاهرًا للقواعد. يعطّل البرامج التي تحلّ الأسماء بنفسها.",
            "fr": "Répond immédiatement depuis une plage privée et garde le domaine visible pour les règles. Casse les logiciels qui résolvent les noms eux-mêmes.",
            "pt": "Responde na hora com uma faixa privada e mantém o domínio visível para as regras. Quebra programas que resolvem os nomes por conta própria.",
            "de": "Antwortet sofort aus einem privaten Bereich und hält die Domain für Regeln sichtbar. Bricht Software, die Namen selbst auflöst.",
            "ja": "プライベート範囲から即座に応答し、ドメインをルールから見えるままにします。自前で名前解決するソフトは動かなくなります。",
            "id": "Menjawab seketika dari rentang privat dan menjaga domain tetap terlihat oleh aturan. Merusak perangkat lunak yang meresolusi nama sendiri.",
            "tr": "Özel bir aralıktan anında yanıt verir ve alan adını kurallara görünür tutar. Adları kendi çözen yazılımları bozar."],
        "Add resolver": [
            "ru": "Добавить резолвер", "zh": "添加解析器", "es": "Añadir resolutor",
            "hi": "रिज़ॉल्वर जोड़ें", "ar": "إضافة محلّل", "fr": "Ajouter un résolveur",
            "pt": "Adicionar resolvedor", "de": "Resolver hinzufügen",
            "ja": "リゾルバを追加", "id": "Tambah resolver", "tr": "Çözücü ekle"],
        "Host or IP": [
            "ru": "Хост или IP", "zh": "主机或 IP", "es": "Host o IP", "hi": "होस्ट या IP",
            "ar": "المضيف أو IP", "fr": "Hôte ou IP", "pt": "Host ou IP", "de": "Host oder IP",
            "ja": "ホストまたは IP", "id": "Host atau IP", "tr": "Ana makine veya IP"],
        "Queries go through": [
            "ru": "Запросы идут через", "zh": "查询经由", "es": "Las consultas pasan por",
            "hi": "क्वेरी इससे जाती हैं", "ar": "تمر الاستعلامات عبر", "fr": "Les requêtes passent par",
            "pt": "As consultas passam por", "de": "Anfragen laufen über",
            "ja": "クエリの経路", "id": "Kueri lewat", "tr": "Sorgular şuradan geçer"],
        "Default route": [
            "ru": "Маршрут по умолчанию", "zh": "默认路由", "es": "Ruta por defecto",
            "hi": "डिफ़ॉल्ट रूट", "ar": "المسار الافتراضي", "fr": "Route par défaut",
            "pt": "Rota padrão", "de": "Standardroute",
            "ja": "既定の経路", "id": "Rute bawaan", "tr": "Varsayılan yol"],
        "Missing outbound": [
            "ru": "Исходящий не найден", "zh": "出站已不存在", "es": "Salida inexistente",
            "hi": "आउटबाउंड मौजूद नहीं", "ar": "وجهة صادرة مفقودة", "fr": "Sortie introuvable",
            "pt": "Saída inexistente", "de": "Ausgang fehlt",
            "ja": "アウトバウンドがありません", "id": "Outbound hilang", "tr": "Çıkış bulunamadı"],
        "DNS rules — first match wins": [
            "ru": "Правила DNS — срабатывает первое совпадение",
            "zh": "DNS 规则 — 先匹配先生效",
            "es": "Reglas DNS: gana la primera coincidencia",
            "hi": "DNS नियम — पहला मिलान लागू",
            "ar": "قواعد DNS — أول تطابق يفوز",
            "fr": "Règles DNS — la première correspondance gagne",
            "pt": "Regras DNS — vence a primeira correspondência",
            "de": "DNS-Regeln — der erste Treffer gewinnt",
            "ja": "DNS ルール — 最初に一致したものが有効",
            "id": "Aturan DNS — kecocokan pertama menang",
            "tr": "DNS kuralları — ilk eşleşme geçerli"],
        "Add DNS rule": [
            "ru": "Добавить правило DNS", "zh": "添加 DNS 规则", "es": "Añadir regla DNS",
            "hi": "DNS नियम जोड़ें", "ar": "إضافة قاعدة DNS", "fr": "Ajouter une règle DNS",
            "pt": "Adicionar regra DNS", "de": "DNS-Regel hinzufügen",
            "ja": "DNS ルールを追加", "id": "Tambah aturan DNS", "tr": "DNS kuralı ekle"],
        "Refuse these names": [
            "ru": "Отклонять эти имена", "zh": "拒绝这些域名", "es": "Rechazar estos nombres",
            "hi": "इन नामों को अस्वीकार करें", "ar": "رفض هذه الأسماء", "fr": "Refuser ces noms",
            "pt": "Recusar estes nomes", "de": "Diese Namen ablehnen",
            "ja": "これらの名前を拒否", "id": "Tolak nama-nama ini", "tr": "Bu adları reddet"],
        "Refused": [
            "ru": "Отклоняется", "zh": "已拒绝", "es": "Rechazado", "hi": "अस्वीकृत",
            "ar": "مرفوض", "fr": "Refusé", "pt": "Recusado", "de": "Abgelehnt",
            "ja": "拒否", "id": "Ditolak", "tr": "Reddedildi"],
        "Same matchers as a routing rule, minus the ones that need an address: a name is being resolved, so there is no destination IP yet.": [
            "ru": "Те же условия, что и в правиле маршрутизации, кроме требующих адреса: имя ещё резолвится, IP назначения пока нет.",
            "zh": "与路由规则相同的匹配条件，但不含需要地址的那些：此时正在解析域名，还没有目标 IP。",
            "es": "Los mismos criterios que en una regla de enrutamiento, salvo los que necesitan una dirección: se está resolviendo un nombre, así que aún no hay IP de destino.",
            "hi": "रूटिंग नियम जैसे ही मैचर, सिवाय उनके जिन्हें पता चाहिए: अभी नाम रिज़ॉल्व हो रहा है, इसलिए गंतव्य IP नहीं है।",
            "ar": "نفس شروط قاعدة التوجيه، باستثناء ما يحتاج إلى عنوان: الاسم قيد التحليل، فلا يوجد عنوان وجهة بعد.",
            "fr": "Les mêmes critères qu'une règle de routage, sauf ceux qui exigent une adresse : un nom est en cours de résolution, il n'y a pas encore d'IP de destination.",
            "pt": "Os mesmos critérios de uma regra de roteamento, menos os que exigem endereço: um nome está sendo resolvido, então ainda não há IP de destino.",
            "de": "Dieselben Kriterien wie bei einer Routing-Regel, ohne die, die eine Adresse brauchen: Ein Name wird gerade aufgelöst, eine Ziel-IP gibt es noch nicht.",
            "ja": "ルーティングルールと同じ条件から、アドレスを必要とするものを除いたものです。名前を解決中なので、宛先 IP はまだありません。",
            "id": "Pencocok yang sama seperti aturan perutean, tanpa yang memerlukan alamat: sebuah nama sedang diresolusi, jadi belum ada IP tujuan.",
            "tr": "Yönlendirme kuralıyla aynı ölçütler, adres gerektirenler hariç: bir ad çözülüyor, bu yüzden henüz hedef IP yok."],
        "Used by the sing-box core. The Xray path uses the plain server list in Settings.": [
            "ru": "Используется ядром sing-box. Ядро Xray берёт простой список серверов из настроек.",
            "zh": "供 sing-box 内核使用。Xray 路径使用设置中的普通服务器列表。",
            "es": "Lo usa el núcleo sing-box. La vía Xray usa la lista simple de servidores de Ajustes.",
            "hi": "sing-box core इसे उपयोग करता है। Xray पथ Settings की सादा सर्वर सूची लेता है।",
            "ar": "تستخدمه نواة sing-box. أما مسار Xray فيستخدم قائمة الخوادم البسيطة في الإعدادات.",
            "fr": "Utilisé par le cœur sing-box. La voie Xray utilise la liste de serveurs simple des réglages.",
            "pt": "Usado pelo núcleo sing-box. O caminho Xray usa a lista simples de servidores nas Configurações.",
            "de": "Wird vom sing-box-Kern genutzt. Der Xray-Weg verwendet die einfache Serverliste in den Einstellungen.",
            "ja": "sing-box コアが使用します。Xray 経路は設定の単純なサーバー一覧を使います。",
            "id": "Dipakai core sing-box. Jalur Xray memakai daftar server sederhana di Pengaturan.",
            "tr": "sing-box çekirdeği kullanır. Xray yolu Ayarlar'daki düz sunucu listesini kullanır."],


        // MARK: TUN + control API
        "TUN": [
            "ru": "TUN", "zh": "TUN", "es": "TUN", "hi": "TUN",
            "ar": "TUN", "fr": "TUN", "pt": "TUN", "de": "TUN",
            "ja": "TUN", "id": "TUN", "tr": "TUN"],
        "Let the core own the interface": [
            "ru": "Пусть ядро само управляет интерфейсом",
            "zh": "由内核自己接管网络接口",
            "es": "Deja que el núcleo gestione la interfaz",
            "hi": "इंटरफ़ेस को core के हवाले करें",
            "ar": "دع النواة تتولى الواجهة",
            "fr": "Laisser le cœur gérer l'interface",
            "pt": "Deixar o núcleo cuidar da interface",
            "de": "Den Kern die Schnittstelle führen lassen",
            "ja": "コアにインターフェースを任せる",
            "id": "Biarkan core menguasai antarmuka",
            "tr": "Arayüzü çekirdek yönetsin"],
        "sing-box handles the tunnel itself, which is what lets a rule match an application. Turn this off to fall back to tun2socks.": [
            "ru": "sing-box сам ведёт туннель — именно это позволяет правилу совпадать с приложением. Отключите, чтобы вернуться к tun2socks.",
            "zh": "sing-box 亲自处理隧道，规则才能匹配到应用。关闭后会退回 tun2socks。",
            "es": "sing-box gestiona el túnel por sí mismo, que es lo que permite que una regla coincida con una aplicación. Desactívalo para volver a tun2socks.",
            "hi": "sing-box खुद टनल संभालता है, इसी से नियम किसी ऐप से मेल खा पाता है। बंद करने पर tun2socks पर लौट आएँगे।",
            "ar": "تتولى sing-box النفق بنفسها، وهذا ما يسمح للقاعدة بمطابقة تطبيق. أوقفه للعودة إلى tun2socks.",
            "fr": "sing-box gère le tunnel lui-même, ce qui permet à une règle de correspondre à une application. Désactivez pour revenir à tun2socks.",
            "pt": "O sing-box cuida do túnel sozinho, e é isso que permite uma regra corresponder a um aplicativo. Desative para voltar ao tun2socks.",
            "de": "sing-box führt den Tunnel selbst — nur so kann eine Regel ein Programm treffen. Ausschalten, um zu tun2socks zurückzukehren.",
            "ja": "sing-box が自らトンネルを扱うため、ルールがアプリに一致できます。オフにすると tun2socks に戻ります。",
            "id": "sing-box menangani terowongan sendiri, dan itulah yang membuat aturan bisa cocok dengan aplikasi. Matikan untuk kembali ke tun2socks.",
            "tr": "Tüneli sing-box kendisi yönetir; bir kuralın uygulamayla eşleşmesini sağlayan budur. Kapatınca tun2socks'a dönülür."],
        "Strict route": [
            "ru": "Строгая маршрутизация", "zh": "严格路由", "es": "Ruta estricta",
            "hi": "सख़्त रूटिंग", "ar": "توجيه صارم", "fr": "Routage strict",
            "pt": "Rota estrita", "de": "Strenge Route",
            "ja": "厳格ルーティング", "id": "Rute ketat", "tr": "Katı yönlendirme"],
        "Stops traffic from leaving around the tunnel. Can break local network access.": [
            "ru": "Не даёт трафику уходить мимо туннеля. Может сломать доступ к локальной сети.",
            "zh": "阻止流量绕过隧道。可能会影响局域网访问。",
            "es": "Impide que el tráfico salga por fuera del túnel. Puede romper el acceso a la red local.",
            "hi": "ट्रैफ़िक को टनल के बाहर जाने से रोकता है। लोकल नेटवर्क एक्सेस टूट सकता है।",
            "ar": "يمنع مرور البيانات خارج النفق. قد يعطّل الوصول إلى الشبكة المحلية.",
            "fr": "Empêche le trafic de sortir en dehors du tunnel. Peut casser l'accès au réseau local.",
            "pt": "Impede que o tráfego saia por fora do túnel. Pode quebrar o acesso à rede local.",
            "de": "Verhindert, dass Verkehr am Tunnel vorbeigeht. Kann den Zugriff aufs lokale Netz brechen.",
            "ja": "トンネルを迂回する通信を止めます。ローカルネットワークへのアクセスが壊れることがあります。",
            "id": "Mencegah trafik keluar di luar terowongan. Bisa merusak akses jaringan lokal.",
            "tr": "Trafiğin tünelin dışından çıkmasını engeller. Yerel ağ erişimini bozabilir."],
        "Stack": [
            "ru": "Стек", "zh": "协议栈", "es": "Pila", "hi": "स्टैक",
            "ar": "الحزمة", "fr": "Pile", "pt": "Pilha", "de": "Stack",
            "ja": "スタック", "id": "Stack", "tr": "Yığın"],
        "Automatic": [
            "ru": "Автоматически", "zh": "自动", "es": "Automático", "hi": "स्वचालित",
            "ar": "تلقائي", "fr": "Automatique", "pt": "Automático", "de": "Automatisch",
            "ja": "自動", "id": "Otomatis", "tr": "Otomatik"],
        "Control API": [
            "ru": "API управления", "zh": "控制 API", "es": "API de control",
            "hi": "कंट्रोल API", "ar": "واجهة التحكم", "fr": "API de contrôle",
            "pt": "API de controle", "de": "Steuerungs-API",
            "ja": "制御 API", "id": "API kontrol", "tr": "Kontrol API'si"],
        "Let other programs configure Veil": [
            "ru": "Разрешить другим программам настраивать Veil",
            "zh": "允许其他程序配置 Veil",
            "es": "Permitir que otros programas configuren Veil",
            "hi": "अन्य प्रोग्राम को Veil कॉन्फ़िगर करने दें",
            "ar": "السماح لبرامج أخرى بضبط Veil",
            "fr": "Autoriser d'autres programmes à configurer Veil",
            "pt": "Permitir que outros programas configurem o Veil",
            "de": "Anderen Programmen erlauben, Veil einzurichten",
            "ja": "他のプログラムに Veil の設定を許可",
            "id": "Izinkan program lain mengonfigurasi Veil",
            "tr": "Başka programların Veil'i yapılandırmasına izin ver"],
        "Not listening": [
            "ru": "Не слушает", "zh": "未监听", "es": "Sin escuchar",
            "hi": "सुन नहीं रहा", "ar": "لا يستمع", "fr": "N'écoute pas",
            "pt": "Não está escutando", "de": "Hört nicht",
            "ja": "待ち受けていません", "id": "Tidak mendengarkan", "tr": "Dinlemiyor"],
        "Token": [
            "ru": "Токен", "zh": "令牌", "es": "Token", "hi": "टोकन",
            "ar": "الرمز", "fr": "Jeton", "pt": "Token", "de": "Token",
            "ja": "トークン", "id": "Token", "tr": "Belirteç"],
        "Token copied": [
            "ru": "Токен скопирован", "zh": "已复制令牌", "es": "Token copiado",
            "hi": "टोकन कॉपी हो गया", "ar": "تم نسخ الرمز", "fr": "Jeton copié",
            "pt": "Token copiado", "de": "Token kopiert",
            "ja": "トークンをコピーしました", "id": "Token disalin", "tr": "Belirteç kopyalandı"],
        "New token": [
            "ru": "Новый токен", "zh": "新令牌", "es": "Nuevo token",
            "hi": "नया टोकन", "ar": "رمز جديد", "fr": "Nouveau jeton",
            "pt": "Novo token", "de": "Neues Token",
            "ja": "新しいトークン", "id": "Token baru", "tr": "Yeni belirteç"],
        "Show": [
            "ru": "Показать", "zh": "显示", "es": "Mostrar", "hi": "दिखाएँ",
            "ar": "إظهار", "fr": "Afficher", "pt": "Mostrar", "de": "Zeigen",
            "ja": "表示", "id": "Tampilkan", "tr": "Göster"],
        "Hide": [
            "ru": "Скрыть", "zh": "隐藏", "es": "Ocultar", "hi": "छिपाएँ",
            "ar": "إخفاء", "fr": "Masquer", "pt": "Ocultar", "de": "Verbergen",
            "ja": "非表示", "id": "Sembunyikan", "tr": "Gizle"],
        "Copy setup for an assistant": [
            "ru": "Скопировать инструкцию для ассистента",
            "zh": "复制给助手的配置说明",
            "es": "Copiar las instrucciones para un asistente",
            "hi": "असिस्टेंट के लिए सेटअप कॉपी करें",
            "ar": "نسخ إعدادات المساعد",
            "fr": "Copier les instructions pour un assistant",
            "pt": "Copiar as instruções para um assistente",
            "de": "Anleitung für einen Assistenten kopieren",
            "ja": "アシスタント用の設定をコピー",
            "id": "Salin panduan untuk asisten",
            "tr": "Bir asistan için kurulumu kopyala"],
        "Clash-compatible API (dashboards)": [
            "ru": "API, совместимый с Clash (панели)",
            "zh": "兼容 Clash 的 API（面板）",
            "es": "API compatible con Clash (paneles)",
            "hi": "Clash-संगत API (डैशबोर्ड)",
            "ar": "واجهة متوافقة مع Clash (لوحات التحكم)",
            "fr": "API compatible Clash (tableaux de bord)",
            "pt": "API compatível com Clash (painéis)",
            "de": "Clash-kompatible API (Dashboards)",
            "ja": "Clash 互換 API（ダッシュボード）",
            "id": "API kompatibel Clash (dasbor)",
            "tr": "Clash uyumlu API (paneller)"],
        "Clash API port": [
            "ru": "Порт Clash API", "zh": "Clash API 端口", "es": "Puerto de la API de Clash",
            "hi": "Clash API पोर्ट", "ar": "منفذ واجهة Clash", "fr": "Port de l'API Clash",
            "pt": "Porta da API Clash", "de": "Port der Clash-API",
            "ja": "Clash API ポート", "id": "Porta API Clash", "tr": "Clash API bağlantı noktası"],
        "Served by the core while connected, for dashboards like Yacd. Its secret changes on every launch.": [
            "ru": "Отдаётся ядром, пока есть подключение, — для панелей вроде Yacd. Его секрет меняется при каждом запуске.",
            "zh": "连接期间由内核提供，供 Yacd 等面板使用。其密钥每次启动都会更换。",
            "es": "Lo sirve el núcleo mientras hay conexión, para paneles como Yacd. Su secreto cambia en cada arranque.",
            "hi": "कनेक्ट रहते हुए core इसे देता है, Yacd जैसे डैशबोर्ड के लिए। इसका सीक्रेट हर लॉन्च पर बदलता है।",
            "ar": "تقدّمه النواة أثناء الاتصال، للوحات مثل Yacd. يتغيّر سرّه في كل تشغيل.",
            "fr": "Servie par le cœur pendant la connexion, pour des tableaux de bord comme Yacd. Son secret change à chaque lancement.",
            "pt": "Servida pelo núcleo enquanto conectado, para painéis como o Yacd. O segredo muda a cada inicialização.",
            "de": "Wird vom Kern während der Verbindung bereitgestellt, für Dashboards wie Yacd. Sein Geheimnis wechselt bei jedem Start.",
            "ja": "接続中にコアが提供します。Yacd などのダッシュボード用で、シークレットは起動ごとに変わります。",
            "id": "Disajikan core selama terhubung, untuk dasbor seperti Yacd. Rahasianya berubah setiap peluncuran.",
            "tr": "Bağlıyken çekirdek tarafından sunulur, Yacd gibi paneller için. Parolası her açılışta değişir."],
        "Listens on 127.0.0.1 only and needs the token. Anything holding it can change where your traffic goes.": [
            "ru": "Слушает только 127.0.0.1 и требует токен. Кто владеет токеном — может менять маршруты вашего трафика.",
            "zh": "仅监听 127.0.0.1 并需要令牌。持有令牌的一方可以改变你的流量走向。",
            "es": "Escucha solo en 127.0.0.1 y exige el token. Quien lo tenga puede cambiar por dónde sale tu tráfico.",
            "hi": "केवल 127.0.0.1 पर सुनता है और टोकन माँगता है। जिसके पास टोकन है, वह आपके ट्रैफ़िक का रास्ता बदल सकता है।",
            "ar": "يستمع على 127.0.0.1 فقط ويتطلب الرمز. من يملكه يستطيع تغيير مسار بياناتك.",
            "fr": "N'écoute que sur 127.0.0.1 et exige le jeton. Quiconque le détient peut changer le chemin de votre trafic.",
            "pt": "Escuta apenas em 127.0.0.1 e exige o token. Quem o tiver pode mudar por onde seu tráfego sai.",
            "de": "Hört nur auf 127.0.0.1 und verlangt das Token. Wer es hat, kann ändern, wohin dein Verkehr geht.",
            "ja": "127.0.0.1 のみで待ち受け、トークンを要求します。トークンを持つ相手は通信の経路を変更できます。",
            "id": "Hanya mendengarkan di 127.0.0.1 dan memerlukan token. Siapa pun yang memegangnya bisa mengubah ke mana trafik Anda pergi.",
            "tr": "Yalnızca 127.0.0.1 üzerinde dinler ve belirteç ister. Belirteci elinde tutan, trafiğinizin nereden geçtiğini değiştirebilir."],

    ]
}
