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
	this.innerValue.longv = v;
	this.t = Type.LONG;
    }
    this(JSON[string] v) {
	this.innerValue.objv = v;
	this.t = Type.OBJ;
    }
    unittest {
	JSON(true);
	JSON(false);
	JSON(1);
	assert(JSON(null).type == Type.OBJ); // assoc
    }
public:
    Type type() { return this.t; }
    bool boolean() {
	return this.innerValue.boolv;
    }
    union InnerValue {
	long longv;
	string strv;
	bool boolv;
	double doublev;
	JSON[] arrayv;
	JSON[string] objv;
    }
    enum Type {
	LONG,
	STR,
	BOOLEAN,
	DOUBLE,
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

    ExpectObj expect(string s) {
	import std.algorithm : max;
	auto e = max(this.p+s.length, this.str.length-1);
	if (s == str[p..e]) {
	    return new ExpectObj(s);
	}
	return null;
    }
    void read(ExpectObj o) {
	if (o is null) {
	    return; 
	}
	return;
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
