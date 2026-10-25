import Foundation

struct AssistantFeature: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case see = "See around you", read = "Read", places = "Signs and places"
        case hazards = "Visible hazards (experimental)", shop = "Shopping and money"
        case kitchen = "Kitchen and food", study = "Study and screens"
        case enterprise = "Enterprise and workplace"
    }
    enum Parser: Hashable { case expiry, receipt, price, recipe }
    /// vision: photo to model · readAloud: on-device OCR only · parse: OCR + local parsing
    /// textAI: OCR on device, then only the text goes to the model · barcode: on-device scan + public product lookup
    /// textOnly: typed input to model, no photo · spell: local
    enum Engine: Hashable { case vision, readAloud, parse(Parser), textAI, barcode, textOnly, spell }

    let id: String
    let title: String
    let symbol: String
    let category: Category
    let engine: Engine
    var instruction = ""
    var caution: String?
    var inputPrompt: String?
    var tip: String?
    var phrases: [String] = []

    var needsImage: Bool { engine != .textOnly && engine != .spell }
    var runsLocally: Bool {
        switch engine { case .readAloud, .parse, .spell: return true; default: return false }
    }
    func resolvedInstruction(input: String?) -> String {
        instruction.replacingOccurrences(of: "{input}", with: (input ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum Caution {
    static let hazard = "Experimental. This can miss or misjudge things and can never tell you something is safe. Keep using your cane, guide dog or usual mobility skills."
    static let medicine = "This only reads printed text. It cannot confirm a dose or whether a medicine is right for you. Check with a pharmacist or doctor."
    static let currency = "Currency identification can be wrong. Ask someone to confirm important notes."
    static let food = "This is a visual guess. It cannot tell whether food is safe, allergen-free or fully cooked."
    static let plant = "Plant identification is a guess. Do not eat or touch a plant because of this."
    static let date = "Dates can be misread. Check the package as well."
}

enum FeatureCatalog {
    static func feature(_ id: String) -> AssistantFeature? { all.first { $0.id == id } }
    static func features(in c: AssistantFeature.Category) -> [AssistantFeature] { all.filter { $0.category == c } }

    private typealias F = AssistantFeature

    static let all: [AssistantFeature] = [
        // See around you
        F(id: "find-object", title: "Find an object", symbol: "magnifyingglass", category: .see, engine: .vision,
          instruction: "The user is looking for: {input}. Say whether it is visible. If it is, say where it appears in the frame (left, centre, right, top, bottom, near or far in the picture). Do not give distances in metres or feet. If not visible, say so and suggest turning slowly and taking another photo.",
          inputPrompt: "What are you looking for?", phrases: ["find my ", "find the ", "help me find "]),
        F(id: "object-position", title: "Where things are", symbol: "arrow.left.and.right", category: .see, engine: .vision,
          instruction: "Describe where the main visible objects appear in the frame: left, centre or right, and foreground or background. Do not give measured distances.", phrases: ["where are things", "where things are"]),
        F(id: "color", title: "Identify color", symbol: "paintpalette", category: .see, engine: .vision,
          instruction: "Name the apparent colour of the main object. Mention that lighting can change how a colour looks.", phrases: ["identify the color", "identify the colour", "announce the color"]),
        F(id: "clothing", title: "Clothing", symbol: "tshirt", category: .see, engine: .vision,
          instruction: "Describe the clothing visible: type, colours, and patterns. Mention visible tags or logos only if readable.", phrases: ["describe the clothing", "what am i wearing", "describe my clothes"]),
        F(id: "room", title: "Room layout", symbol: "sofa", category: .see, engine: .vision,
          instruction: "Describe the visible furniture and layout of the room, with rough positions in the frame. Do not claim the floor is clear or safe to walk.", phrases: ["describe the room", "describe this room"]),
        F(id: "door-window", title: "Doors and windows", symbol: "door.left.hand.closed", category: .see, engine: .vision,
          instruction: "Point out any doors or windows that are visible, where they appear in the frame, and whether they look open or closed. State uncertainty.", phrases: ["find the door", "find the window", "doors and windows"]),
        F(id: "belongings", title: "Personal items", symbol: "bag", category: .see, engine: .vision,
          instruction: "List personal items visible (for example phone, keys, wallet, bag, glasses) and where they appear. Do not claim any item belongs to the user.", phrases: ["what items", "personal items"]),
        F(id: "plant", title: "Plants and flowers", symbol: "leaf", category: .see, engine: .vision,
          instruction: "Say what kind of plant or flower this most likely is, with your confidence. Offer one or two alternatives if unsure. Never say it is edible, safe or poisonous.", caution: Caution.plant, phrases: ["identify the plant", "identify this plant", "what flower"]),
        F(id: "animal", title: "Animals", symbol: "pawprint", category: .see, engine: .vision,
          instruction: "Describe any animals visible: kind, size relative to the frame, colours, and what they appear to be doing. Do not judge whether an animal is friendly or dangerous.", phrases: ["what animal", "identify the animal"]),

        // Read
        F(id: "book", title: "Book page", symbol: "book", category: .read, engine: .readAloud, tip: "Hold the page flat and fill the frame.", phrases: ["read the book", "read this page", "read this book"]),
        F(id: "document", title: "Letter or document", symbol: "doc.text", category: .read, engine: .readAloud, phrases: ["read the letter", "read this document", "read the document"]),
        F(id: "textbook", title: "Textbook", symbol: "text.book.closed", category: .read, engine: .readAloud, phrases: ["read the textbook"]),
        F(id: "menu", title: "Menu", symbol: "fork.knife", category: .read, engine: .readAloud, phrases: ["read the menu", "read this menu"]),
        F(id: "medicine", title: "Medicine label", symbol: "pills", category: .read, engine: .readAloud, caution: Caution.medicine, phrases: ["read the medicine", "medicine label"]),
        F(id: "expiry", title: "Expiry date", symbol: "calendar.badge.clock", category: .read, engine: .parse(.expiry), caution: Caution.date, phrases: ["expiry date", "expiration date", "when does this expire"]),
        F(id: "bill", title: "Bill or invoice", symbol: "doc.plaintext", category: .read, engine: .textAI,
          instruction: "From this OCR text of a bill or invoice, state who it is from, the total amount due, the due date, and any account reference. Only use what is in the text; say 'not shown' otherwise. Then list the main line items.", phrases: ["read the bill", "read this bill", "read the invoice"]),
        F(id: "receipt", title: "Receipt total", symbol: "receipt", category: .read, engine: .parse(.receipt), phrases: ["read the receipt", "receipt total", "what is the total"]),
        F(id: "handwriting", title: "Handwriting", symbol: "pencil.line", category: .read, engine: .vision,
          instruction: "Transcribe any legible handwriting exactly. Mark words you cannot read as [unclear]. Do not guess missing words.", phrases: ["read the handwriting", "read this handwriting"]),
        F(id: "summarize", title: "Summarize a document", symbol: "text.append", category: .read, engine: .textAI,
          instruction: "Summarise this OCR text in plain spoken language: a two-sentence overview, then the key points. Do not add facts that are not in the text.", phrases: ["summarize this", "summarise this", "summarize the document"]),
        F(id: "translate", title: "Translate text in photo", symbol: "character.bubble", category: .read, engine: .textAI,
          instruction: "Translate this OCR text into the reply language. If no other language was requested, use English. Keep names and numbers unchanged and say if parts were unreadable.", phrases: ["translate this", "translate the text"]),
        F(id: "multilingual", title: "Read other languages", symbol: "globe", category: .read, engine: .readAloud, tip: "Text is read by the voice for your chosen language.", phrases: ["read in hindi", "read in kannada"]),

        // Signs and places
        F(id: "signboard", title: "Signs and boards", symbol: "signpost.right", category: .places, engine: .readAloud, phrases: ["read the sign", "read the signboard", "read the board"]),
        F(id: "bus-stop", title: "Bus stop sign", symbol: "bus", category: .places, engine: .vision,
          instruction: "Read the bus stop name and any route numbers or timetable text that are visible. Do not guess unreadable text.", phrases: ["bus stop sign", "read the bus stop"]),
        F(id: "bus-number", title: "Bus number", symbol: "bus.fill", category: .places, engine: .vision,
          instruction: "Read the bus route number and destination shown on the vehicle, if clearly visible. If not clear, say so. Do not guess.", phrases: ["bus number", "which bus"]),
        F(id: "platform", title: "Platform sign", symbol: "tram.fill", category: .places, engine: .vision,
          instruction: "Read the platform number and train or destination information on visible signs. Do not guess unreadable text.", phrases: ["platform sign", "which platform"]),
        F(id: "doorway", title: "Find the entrance", symbol: "rectangle.portrait.and.arrow.right", category: .places, engine: .vision,
          instruction: "Say whether an entrance or doorway is visible and where it appears in the frame. State uncertainty. Do not say the way to it is clear.", caution: Caution.hazard, phrases: ["find the entrance", "find the doorway"]),

        // Hazards
        F(id: "obstacles", title: "Objects in the way", symbol: "exclamationmark.triangle", category: .hazards, engine: .vision,
          instruction: "List objects visible that might be in the way, with where they appear in the frame. Never say the path is clear or safe. End by noting what the image cannot show.", caution: Caution.hazard, phrases: ["what is in the way", "obstacles"]),
        F(id: "stairs", title: "Stairs", symbol: "stairs", category: .hazards, engine: .vision,
          instruction: "Say whether stairs, steps or a ramp appear to be visible, with your confidence. Do not state how many or how steep unless clearly countable. Never state it is safe.", caution: Caution.hazard, phrases: ["are there stairs", "any stairs"]),
        F(id: "curb", title: "Curb edge", symbol: "road.lanes", category: .hazards, engine: .vision,
          instruction: "Say whether a curb or road edge appears visible, with confidence. Never say it is safe to step or cross.", caution: Caution.hazard, phrases: ["is there a curb", "is there a kerb"]),
        F(id: "crossing", title: "Crossing signal", symbol: "figure.walk", category: .hazards, engine: .vision,
          instruction: "Describe any visible pedestrian signal (its apparent state), crosswalk markings, and vehicles in the frame. Never say it is safe to cross; a single photo cannot show traffic.", caution: Caution.hazard, phrases: ["crossing signal", "can i cross"]),
        F(id: "wet-floor", title: "Warning signs", symbol: "exclamationmark.octagon", category: .hazards, engine: .readAloud, caution: "Reads visible sign text only. Absence of a sign does not mean there is no hazard.", phrases: ["wet floor", "warning sign"]),
        F(id: "warning-label", title: "Hazard labels", symbol: "flame", category: .hazards, engine: .readAloud, caution: "Reads printed label text only. Follow the manufacturer's instructions.", phrases: ["warning label", "hazard label"]),
        F(id: "smoke-fire", title: "Smoke or fire in view", symbol: "smoke", category: .hazards, engine: .vision,
          instruction: "Say whether anything in the image looks like smoke, flames or a fire alarm, with confidence. If it might be, tell the user to leave and call emergency services. If nothing is seen, say that this does not prove there is no fire.", caution: "Not a fire detector. If you smell smoke or hear an alarm, leave and call emergency services.", phrases: ["is there smoke", "is there fire"]),

        // Shopping
        F(id: "product-name", title: "Product name", symbol: "shippingbox", category: .shop, engine: .vision,
          instruction: "Read the product name, brand and size or weight printed on the packaging. Do not guess; say if unreadable.", phrases: ["what product", "product name"]),
        F(id: "barcode", title: "Barcode scanner", symbol: "barcode.viewfinder", category: .shop, engine: .barcode,
          tip: "Hold the barcode flat. Only the number is sent to the public Open Food Facts database.", phrases: ["scan the barcode", "scan barcode"]),
        F(id: "price", title: "Price tag", symbol: "tag", category: .shop, engine: .parse(.price), phrases: ["read the price", "price tag", "how much is"]),
        F(id: "clothing-tag", title: "Clothing tag", symbol: "tag.circle", category: .shop, engine: .readAloud, phrases: ["clothing tag", "care instructions"]),
        F(id: "currency", title: "Currency notes", symbol: "indianrupeesign.circle", category: .shop, engine: .vision,
          instruction: "State the currency and denomination printed on any banknote visible. If there is any doubt, say so clearly. Do not state whether a note is genuine.", caution: Caution.currency, phrases: ["identify the note", "which note", "currency note"]),
        F(id: "shelf-finder", title: "Find on a shelf", symbol: "books.vertical", category: .shop, engine: .vision,
          instruction: "The user wants to find: {input}. Say whether it is visible on the shelf and where in the frame (which shelf row from the top, left, centre or right). Say if unsure.",
          inputPrompt: "What product do you want?", phrases: ["find on the shelf", "on the shelf"]),

        // Kitchen
        F(id: "food", title: "Identify food", symbol: "carrot", category: .kitchen, engine: .vision,
          instruction: "Say what food this most likely is and describe how it looks. Never say it is safe to eat, fresh, allergen-free or fully cooked.", caution: Caution.food, phrases: ["what food", "identify the food"]),
        F(id: "ingredients", title: "Ingredient label", symbol: "list.bullet.rectangle", category: .kitchen, engine: .readAloud, caution: "Reads printed text only. Always check labels yourself for allergies.", phrases: ["read the ingredients", "ingredient list"]),
        F(id: "nutrition", title: "Nutrition label", symbol: "chart.bar.doc.horizontal", category: .kitchen, engine: .textAI,
          instruction: "From this OCR text of a nutrition label, state serving size, calories, and the main nutrients listed with their amounts. Only use values in the text. Make no health judgement.", phrases: ["nutrition label", "nutrition facts", "how many calories"]),
        F(id: "recipe", title: "Recipe, step by step", symbol: "list.number", category: .kitchen, engine: .parse(.recipe),
          tip: "After loading, say 'next step', 'previous step' or 'repeat' in Ask a Question.", phrases: ["read the recipe", "start the recipe"]),
        F(id: "utensil", title: "Kitchen tools", symbol: "wrench.and.screwdriver", category: .kitchen, engine: .vision,
          instruction: "Identify the cooking tools or utensils visible and where they appear in the frame. State uncertainty.", phrases: ["kitchen tool", "which utensil"]),
        F(id: "appliance", title: "Appliance buttons", symbol: "washer", category: .kitchen, engine: .vision,
          instruction: "Read the visible button labels, dial markings and display text on this appliance and say where each is in the frame. Do not guess unreadable labels or explain safety settings.", phrases: ["read the appliance", "read the buttons"]),

        // Study and screens
        F(id: "diagram", title: "Diagram", symbol: "chart.xyaxis.line", category: .study, engine: .vision,
          instruction: "Explain this diagram in plain spoken language: what it shows, its labelled parts, and how they connect. Say if labels are unreadable.", phrases: ["explain the diagram", "explain this diagram"]),
        F(id: "chart", title: "Chart or graph", symbol: "chart.bar", category: .study, engine: .vision,
          instruction: "Explain this chart: title, axes and units, and the main trend or comparison that is readable. Do not invent values you cannot read.", phrases: ["explain the chart", "explain this chart", "explain the graph"]),
        F(id: "math", title: "Math expressions", symbol: "function", category: .study, engine: .vision,
          instruction: "Read this mathematical expression aloud in words, exactly as written. Do not solve it unless asked.", phrases: ["read the equation", "read the math", "read this equation"]),
        F(id: "screenshot", title: "Screen or screenshot", symbol: "iphone", category: .study, engine: .vision,
          instruction: "Describe this screen: the app or page, the main text, and the visible buttons, fields and menus, in reading order.", phrases: ["describe the screen", "explain the screenshot"]),
        F(id: "vocabulary", title: "Word meaning", symbol: "character.book.closed", category: .study, engine: .textOnly,
          instruction: "Explain the word or phrase '{input}' simply, with one short example sentence.", inputPrompt: "Which word?", phrases: ["what does the word ", "meaning of ", "define "]),
        F(id: "spelling", title: "Spell a word", symbol: "textformat.abc", category: .study, engine: .spell,
          inputPrompt: "Which word?", phrases: ["spell "]),
        F(id: "quiz", title: "Practice questions", symbol: "questionmark.bubble", category: .study, engine: .textAI,
          instruction: "From this OCR text, make five short spoken practice questions. Put the questions in 'summary' and the answers in 'detail'. Use only the text.", phrases: ["quiz me", "practice questions"]),

        // Australian Community Impact (Sydney & Local Context)
        F(id: "sydney-transit", title: "Sydney transport & Opal", symbol: "tram.fill", category: .places, engine: .vision,
          instruction: "Read visible Sydney public transport signs (Sydney Trains, Metro, Light Rail, Bus, Ferry) and Opal card readers. Mention platform, destination, and departure information clearly visible. Do not guess unreadable text.", phrases: ["sydney transport", "opal card", "metro sign", "which platform"]),
        F(id: "aud-note", title: "Australian banknotes (AUD)", symbol: "dollarsign.circle", category: .shop, engine: .vision,
          instruction: "Identify the Australian banknote visible: $5, $10, $20, $50, or $100 note. Mention the color (e.g. purple $5, blue $10, red-orange $20, yellow $50, green $100) and tactile features. Note uncertainty clearly.", caution: Caution.currency, phrases: ["identify aud", "australian note", "australian dollar", "which australian note"]),

        // Enterprise & Workplace Inspection
        F(id: "meter-reader", title: "Gauge & meter reader", symbol: "gauge.with.needle", category: .enterprise, engine: .vision,
          instruction: "Read the visible dial, gauge or digital display. State the current indicated value, unit of measurement (such as bar, PSI, volts, celsius), and whether the needle appears in a normal or alert zone if visible. Never claim equipment is hazard-free.", caution: "Verification tool only. Follow facility safety protocols and verify critical readings with physical gauges.", phrases: ["read the gauge", "gauge reader", "pressure reading", "meter reading"]),
        F(id: "ppe-inspection", title: "Workplace PPE & safety audit", symbol: "shield.checkered", category: .enterprise, engine: .vision,
          instruction: "Audit visible personal protective equipment (PPE) such as high-visibility vests, hard hats, safety glasses, or boots. Note any visible safety equipment present or missing on individuals in view, and identify any blocked fire exits or tripping hazards. Never certify an area as completely safe or compliant.", caution: "Assistive audit only. Does not replace professional Work Health and Safety (WHS) officer inspection.", phrases: ["check ppe", "safety audit", "workplace safety", "ppe check"]),
        F(id: "asset-tag", title: "Machinery serial & asset tag", symbol: "barcode", category: .enterprise, engine: .vision,
          instruction: "Extract the manufacturer model number, serial number, and inspection or calibration dates printed on this industrial equipment asset tag. Spell out alphanumeric codes clearly. Mark unreadable characters as [unclear].", phrases: ["asset tag", "serial number", "equipment label", "machinery tag"]),
        F(id: "logistics-slip", title: "Shipping manifest & cargo audit", symbol: "shippingbox.and.arrow.backward", category: .enterprise, engine: .textAI,
          instruction: "From this OCR text of a shipping manifest or bill of lading, extract consignee, tracking number, package count, weight, and delivery destination. List visible line items and note if any portion was unreadable.", phrases: ["shipping slip", "cargo manifest", "bill of lading", "verify shipment"])
    ]
}
