module jparse;

struct JSON {
private:
    InnerValue innerValue;
    Type t = Type.OBJ;

public:
    union InnerValue {
	long numberv;
	string strv;
	bool boolv;
	double floatingv;
	JSON[] arrayv;
	JSON[string] objv;
    }
    enum Type {
	NUMBER,
	STR,
	BOOLEAN,
	FLOATING,
	ARRAY,
	OBJ
    }

    this(bool v) {
	this.innerValue.boolv = v;
	this.t = Type.BOOLEAN;
    }
    this(int v) {
	this.innerValue.numberv = v;
	this.t = Type.NUMBER;
    }
    this(long v) {
	this.innerValue.numberv = v;
	this.t = Type.NUMBER;
    }
    this(double v) {
	this.innerValue.floatingv = v;
	this.t = Type.FLOATING;
    }
    this(string v) {
	this.innerValue.strv = v;
	this.t = Type.STR;
    }
    this(JSON[] v) {
	this.innerValue.arrayv = v;
	this.t = Type.ARRAY;
    }
    this(JSON[string] v) {
	this.innerValue.objv = v;
	this.t = Type.OBJ;
    }
    unittest {
	assert(JSON(true).type == Type.BOOLEAN);
	assert(JSON(false).type == Type.BOOLEAN);
	assert(JSON(1).type == Type.NUMBER);
	assert(JSON(1.1).type == Type.FLOATING);
	assert(JSON("hello").type == Type.STR);
	assert(JSON([JSON(true), JSON(1)]).type == Type.ARRAY);
    }

    //TODO: make me const
    bool opEquals(JSON json) {
	if (this.type != json.type) {
	    return false;
	}
	final switch (this.type) {
	case Type.BOOLEAN:
	    return this.boolean == json.boolean;
	case Type.NUMBER:
	    return this.number == json.number;
	case Type.FLOATING:
	    return this.floating == json.floating;
	case Type.STR:
	    return this.str == json.str;
	case Type.ARRAY:
	    import std.range:zip;
	    import std.algorithm:all;
	    return this.array.length == json.array.length &&
		all!"a[0] == a[1]"(zip(this.array, json.array));
	case Type.OBJ:
	    if (this.obj.length != json.obj.length) {
		return false;
	    }
	    bool all = true;
	    foreach (k,v; this.obj) {
		if (k !in json.obj || v != json.obj[k]) {
		    all = false;
		    break;
		}
	    }
	    return all;
	}
    }
    unittest {
	assert(JSON(1) == JSON(1));
	assert([JSON(1)] == [JSON(1)]);
	assert(JSON([JSON(1)]) == JSON([JSON(1)]));
	assert(JSON(true) == JSON(true));
    }

    Type type() const { return this.t; }
    bool boolean() const {
	return this.innerValue.boolv;
    }
    long number() const {
	return this.innerValue.numberv;
    }
    double floating() const {
	return this.innerValue.floatingv;
    }
    string str() const {
	return this.innerValue.strv;
    }
    JSON[] array() const {
	return this.innerValue.arrayv.dup;
    }
    JSON[string] obj() {
	return this.innerValue.objv;
    }
}

class ParseInfo {
public:
    string str;
    int p;

    this(string str) {
	this.str = str;
	this.p = 0;
    }

    bool isEnd() {
	return this.p >= this.str.length;
    }

    uint ignoreSpace() {
	import std.algorithm:canFind;
	return ignorePred(x => [' ', '\t', '\n', '\r'].canFind(x));
    }

    uint ignorePred(bool delegate(char) pred) {
	uint cnt = 0;
	while (!this.isEnd() && pred(this.str[this.p])) {
	    cnt++;
	    this.p++;
	}
	return cnt;
    }

    class ExpectObj {
    public:
	string s;
	this(string s) {
	    this.s = s;
	}
    }

    ExpectObj expect(bool delegate(char) pred) {
	import std.conv : to;

	if (!this.isEnd() && pred(this.str[this.p])) {
	    return new ExpectObj(this.str[this.p].to!string);
	}
	return null;
    }

    ExpectObj expect(string s) {
	import std.algorithm : min;

	ignoreSpace();
	auto e = min(this.p+s.length, this.str.length);
	if (s == str[p..e]) {
	    return new ExpectObj(s);
	}
	return null;
    }
    string read(ExpectObj o) {
	if (o is null) {
	    return null;  
	}
	int pre = this.p;
	this.p += o.s.length;
	return this.str[pre..this.p];
    }

    char get() {
	char c = this.str[this.p];
	this.p++;
	return c;
    }
}

bool tryParseBool(ParseInfo pinfo, ref JSON boolObj) {
    if (auto ex = pinfo.expect("true")) {
	pinfo.read(ex);
	boolObj = JSON(true);
	return true;
    }
    if (auto ex = pinfo.expect("false")) {
	pinfo.read(ex);
	boolObj = JSON(false);
	return true;
    }
    return false;
}

unittest {
    {
	JSON boolObj;
	assert(tryParseBool(new ParseInfo("true"), boolObj) == true);
	assert(boolObj.type == JSON.Type.BOOLEAN);
	assert(boolObj.boolean == true);
    }

    {
	JSON boolObj;
	assert(tryParseBool(new ParseInfo("false"), boolObj) == true);
	assert(boolObj.type == JSON.Type.BOOLEAN);
	assert(boolObj.boolean == false);
    }

    {
	JSON boolObj;
	assert(tryParseBool(new ParseInfo("faust"), boolObj) == false);
	assert(boolObj.type == JSON.Type.OBJ);
    }
}

bool tryParseNumber(ParseInfo pinfo, ref JSON numberObj) {
    import std.conv : to;
    int p = pinfo.p;

    bool isNegative = false;
    if (auto ex = pinfo.expect("-")) {
	pinfo.read(ex);
	isNegative = true;
    }

    if (auto ex = pinfo.expect("0.")) {
	pinfo.p = p;
	return false;
    }

    if (auto ex = pinfo.expect("0e")) {
	pinfo.p = p;
	return false;
    }

    if (auto ex = pinfo.expect(x => '1' <= x && x <= '9')) {
	char[] s = [];
	while (true) {
	    auto ex2 = pinfo.expect(x => '0' <= x && x <= '9');
	    if (ex2 is null) { break; }
	    s ~= pinfo.read(ex2);
	}

	// float
	if (auto dot = pinfo.expect(".")) {
	    pinfo.read(dot);
	    char[] s2 = [];
	    while (true) {
		auto ex2 = pinfo.expect(x => '0' <= x && x <= '9');
		if (ex2 is null) { break; }
		s2 ~= pinfo.read(ex2);
	    }
	    double v = to!double(s~"."~s2);
	    if (isNegative) { v = -v; }
	    numberObj = JSON(v);
	    return true;
	}
	// int
	else {
	    long v = to!long(s);
	    if (isNegative) { v = -v; }
	    numberObj = JSON(v);
	    return true;
	}
    }
    pinfo.p = p;
    return false;
}

unittest {
    {
	JSON numberObj;
	assert(tryParseNumber(new ParseInfo("112"), numberObj) == true);
	assert(numberObj.type == JSON.Type.NUMBER);
	assert(numberObj.number == 112);
    }
    {
	JSON numberObj;
	assert(tryParseNumber(new ParseInfo("-112"), numberObj) == true);
	assert(numberObj.type == JSON.Type.NUMBER);
	assert(numberObj.number == -112);
    }
    {
	JSON numberObj;
	assert(tryParseNumber(new ParseInfo("123.4"), numberObj) == true);
	assert(numberObj.type == JSON.Type.FLOATING);
	assert(numberObj.floating == 123.4);
    }
    {
	JSON numberObj;
	assert(tryParseNumber(new ParseInfo("-123.4"), numberObj) == true);
	assert(numberObj.type == JSON.Type.FLOATING);
	assert(numberObj.floating == -123.4);
    }
    {
	JSON numberObj;
	assert(tryParseNumber(new ParseInfo("-"), numberObj) == false);
    }
}

bool tryParseStr(ParseInfo pinfo, ref JSON strObj) {
    auto p = pinfo.p;
    if (auto ex = pinfo.expect("\"")) {
	pinfo.read(ex);
	char[] s = [];
	while (!pinfo.isEnd()) {
	    char c = pinfo.get();
	    if (c == '\\') {
		if (pinfo.isEnd()) {
		    pinfo.p = p;
		    return false;
		}
		char c2 = pinfo.get();
		switch (c2) {
		case '"':
		    s ~= c2;
		    break;
		default:
		    s ~= c;
		    s ~= c2;
		    break;
		}
	    }
	    else if (c == '"') {
		break;
	    }
	    else {
		s ~= c;
	    }
	}
	import std.conv : to;
	strObj = JSON(s.to!string);
	return true;
    }

    pinfo.p = p;
    return false;
}


unittest {
    {
	JSON strObj;
	assert(tryParseStr(new ParseInfo("\"hello\""), strObj) == true);
	assert(strObj.type == JSON.Type.STR);
	assert(strObj.str == "hello");
    }
    {
	JSON strObj;
	assert(tryParseStr(new ParseInfo("\"hello\\\"\""), strObj) == true);
	assert(strObj.type == JSON.Type.STR);
	assert(strObj.str == "hello\"");
    }
}

bool tryParseArray(ParseInfo pinfo, ref JSON arrObj) {
    auto p = pinfo.p;

    if (auto ex = pinfo.expect("[")) {
	pinfo.read(ex);

	JSON[] arr = [];
	if (auto ex2 = pinfo.expect("]")) {
	    pinfo.read(ex2);
	    arrObj = JSON(arr);
	    return true;
	}
	while (true) {
	    JSON jsonObj;
	    if (! tryParseJSON(pinfo, jsonObj)) {
		pinfo.p = p;
		return false;
	    }
	    arr ~= jsonObj;
	    auto ex2 = pinfo.expect(",");
	    if (ex2 is null) {
		auto ex3 = pinfo.expect("]");
		if (ex3 is null) {
		    pinfo.p = p;
		    return false;
		}
		pinfo.read(ex3);
		break;
	    }
	    pinfo.read(ex2);
	}
	arrObj = JSON(arr);
	return true;
    }

    pinfo.p = p;
    return false;
}
unittest {
    {
	JSON arrObj;
	assert(tryParseArray(new ParseInfo("[]"), arrObj) == true);
	assert(arrObj.type == JSON.Type.ARRAY);
	assert(arrObj.array == []);
    }
    {
	JSON arrObj;
	assert(tryParseArray(new ParseInfo("[1]"), arrObj) == true);
	assert(arrObj.type == JSON.Type.ARRAY);
	assert(arrObj.array[0].number == 1);
	assert(arrObj == JSON([JSON(1)]));
    }
    {
	JSON arrObj;
	assert(tryParseArray(new ParseInfo("[1, 2, true, false, \"hello\", [1]]"), arrObj) == true);
	assert(arrObj.type == JSON.Type.ARRAY);
	assert(arrObj.array[0].number == 1);
	assert(arrObj.array[1].number == 2);
	assert(arrObj.array[2].boolean == true);
	assert(arrObj.array[3].boolean == false);
	assert(arrObj.array[4].str == "hello");
	assert(arrObj.array[5].array[0].number == 1);
    }
}

bool tryParseObj(ParseInfo pinfo, ref JSON objObj) {
    auto p = pinfo.p;

    if (auto ex = pinfo.expect("{")) {
	pinfo.read(ex);

	JSON[string] obj;
	if (auto ex2 = pinfo.expect("}")) {
	    pinfo.read(ex2);
	    objObj = JSON(obj);
	    return true;
	}
	while (true) {
	    JSON name;
	    if (! tryParseStr(pinfo, name)) {
		pinfo.p = p;
		return false;
	    }

	    auto colon = pinfo.expect(":");
	    if (colon is null) {
		pinfo.p = p;
		return false;
	    }
	    pinfo.read(colon);

	    JSON jsonObj;
	    if (! tryParseJSON(pinfo, jsonObj)) {
		pinfo.p = p;
		return false;
	    }

	    obj[name.str] = jsonObj;
	    auto ex2 = pinfo.expect(",");
	    if (ex2 is null) {
		auto ex3 = pinfo.expect("}");
		if (ex3 is null) {
		    pinfo.p = p;
		    return false;
		}
		pinfo.read(ex3);
		break;
	    }
	    pinfo.read(ex2);
	}
	objObj = JSON(obj);
	return true;
    }

    pinfo.p = p;
    return false;
}

unittest {
    {
	JSON objObj;
	assert(tryParseObj(new ParseInfo("{}"), objObj)== true);
	assert(objObj.type == JSON.Type.OBJ);
	assert(objObj.obj.length == 0);
    }
    {
	JSON objObj;
	assert(tryParseObj(new ParseInfo("{\"key\":true}"), objObj)== true);
	assert(objObj.type == JSON.Type.OBJ);
	assert(objObj.obj.length == 1);
	assert(objObj == JSON(["key": JSON(true)]));
    }
    {
	JSON objObj;
	assert(tryParseObj(new ParseInfo("{\"key\": {\"key\": \"value\"}, \"key2\": 1}"), objObj)== true);
	assert(objObj.type == JSON.Type.OBJ);
	assert(objObj.obj.length == 2);
	assert(objObj.obj["key"].obj["key"] == JSON("value"));
	assert(objObj.obj["key2"] == JSON(1));
    }
}

bool tryParseJSON(ParseInfo pinfo, ref JSON jsonObj) {
    if (tryParseBool(pinfo, jsonObj)) {
	return true;
    }
    if (tryParseNumber(pinfo, jsonObj)) {
	return true;
    }
    if (tryParseStr(pinfo, jsonObj)) {
	return true;
    }
    if (tryParseArray(pinfo, jsonObj)) {
	return true;
    }
    if (tryParseObj(pinfo, jsonObj)) {
	return true;
    }

    // parse for obj
    return false;
}

// parse JSON string
bool tryParseJSON(string str, ref JSON jsonObj) {
    ParseInfo pinfo = new ParseInfo(str);
    return tryParseJSON(pinfo, jsonObj);
}

unittest {
    {
	JSON json;
	assert(tryParseJSON("true", json) == true); 
	assert(json.type == JSON.Type.BOOLEAN);
	assert(json.boolean == true);
    }
    {
	JSON json;
	assert(tryParseJSON("false", json) == true); 
	assert(json.type == JSON.Type.BOOLEAN);
	assert(json.boolean == false);
    }
    {
	JSON json;
	string jsonStr = `
	{
	    "key": "value",
	    "key": "override",
	    "key2": [ "array", "values", 1],
	    "numkey": 1,
	    "negkey": -1,
	    "floatkey": 1.1,
	    "negfloat": -1.2,
	    "boolean": [ true, false],
	    "objinobj": {
		"empty": {},
		"emptryarr": []
	    }
	}
	`;
	assert(tryParseJSON(jsonStr, json) == true); 
	assert(json.type == JSON.Type.OBJ);
	assert(json == JSON([
	    "key": JSON("override"),
	    "key2": JSON([JSON("array"), JSON("values"), JSON(1)]),
	    "numkey": JSON(1),
	    "negkey": JSON(-1),
	    "floatkey": JSON(1.1),
	    "negfloat": JSON(-1.2),
	    "boolean": JSON([JSON(true), JSON(false)]),
	    "objinobj": JSON([
		"empty": JSON(),
		"emptryarr": JSON(cast(JSON[])[]),
	    ])

	]));
    }
}


