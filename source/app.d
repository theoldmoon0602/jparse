import std.stdio;


struct JSON {
private:
    InnerValue innerValue;
    Type t = Type.OBJ;

    this(bool v) {
	this.innerValue.boolv = v;
	this.t = Type.BOOLEAN;
    }
    this(long v) {
	this.innerValue.numberv = v;
	this.t = Type.NUMBER;
    }
    this(double v) {
	this.innerValue.floatingv = v;
	this.t = Type.FLOATING;
    }
    this(JSON[string] v) {
	this.innerValue.objv = v;
	this.t = Type.OBJ;
    }
    unittest {
	JSON(true);
	JSON(false);
	JSON(1);
	JSON(1.1);
	assert(JSON(null).type == Type.OBJ); // assoc
    }
public:
    Type type() { return this.t; }
    bool boolean() {
	return this.innerValue.boolv;
    }
    long number() {
	return this.innerValue.numberv;
    }
    double floating() {
	return this.innerValue.floatingv;
    }
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
}

class ParseInfo {
public:
    string str;
    int p;

    this(string str) {
	this.str = str;
	this.p = 0;
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

	if (this.p < str.length && pred(str[this.p])) {
	    return new ExpectObj(str[this.p].to!string);
	}
	return null;
    }

    ExpectObj expect(string s) {
	import std.algorithm : min;
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

    bool isNegative = false;
    if (auto ex = pinfo.expect("-")) {
	pinfo.read(ex);
	isNegative = true;
    }

    if (auto ex = pinfo.expect("0.")) {
	return false;
    }

    if (auto ex = pinfo.expect("0e")) {
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


JSON parseJSON(ParseInfo pinfo) {
    if (pinfo.p >= pinfo.str.length) {
	return JSON(null);
    }

    JSON jsonObj;
    if (tryParseBool(pinfo, jsonObj)) {
	return jsonObj;
    }


    // parse for number
    // parse for string
    // parse for array
    // parse for obj
    return JSON(null);
}

// parse JSON string
JSON parseJSON(string str) {
    ParseInfo pinfo = new ParseInfo(str);
    return parseJSON(pinfo);
}

unittest {
    {
	auto json = parseJSON("");
	assert(json.type == JSON.Type.OBJ);
    }
    {
	auto json = parseJSON("true"); 
	assert(json.type == JSON.Type.BOOLEAN);
	assert(json.boolean == true);
    }
    {
	auto json = parseJSON("false"); 
	assert(json.type == JSON.Type.BOOLEAN);
	assert(json.boolean == false);
    }
}


void main()
{
	writeln("Edit source/app.d to start your project.");
}
