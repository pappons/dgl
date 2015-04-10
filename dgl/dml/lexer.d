module dgl.dml.lexer;

import std.stdio;
import std.algorithm;
import std.ascii;
import dlib.container.array;
import dgl.dml.utf8;

struct Lexeme
{
    bool valid = true;
    DynamicArray!(dchar, 32) str;

    void free()
    {
        str.free();
    }
}

enum
{
    FULL_MATCH,
    PARTIAL_MATCH,
    CANDIDATE_MATCH,
    NO_MATCH
}

Lexeme emptyLexeme()
{
    Lexeme lexeme;
    return lexeme;
}

Lexeme invalidLexeme()
{
    Lexeme lexeme;
    lexeme.valid = false;
    return lexeme;
}

//version = LexerDebug;

/*
 * GC-free, Unicode-aware lexical analyzer.
 * Assumes ASCII or UTF-8 input. Outputs arrays of dchars as lexemes.
 * Reads character stream one-by-one.
 * Treats LF (\n) as a newline character on all systems
 * (compatible with Windows and all Unices).
 * Implemented as a chain of filters
 * (stream -> basic lexemes -> with strings -> filtered comments).
 */

struct BaseFilter
{
    UTF8Decoder dec;
    string[] delimiters;
    uint line = 1;

    this(string str)
    {
        this.dec = UTF8Decoder(str);
    }

    Lexeme lexeme1;
    Lexeme lexeme2;
    bool nextIsMatch = false;
    int initNextLexeme2 = -1;
    Lexeme get()
    {
        if (lexeme1.str.data.length)
        {
            auto res = lexeme1;
            lexeme1 = emptyLexeme();
            return res;
        }

        int c = 0;
        while (c != UTF8_END && c != UTF8_ERROR)
        {
            if (initNextLexeme2 >= 0)
            {
                c = initNextLexeme2;
                initNextLexeme2 = -1;
            }
            else
            {
                c = dec.decodeNext();
                if (cast(dchar)c == '\n')
                    line++;
            }

            if (c < 0) break;

            lexeme2.str.append(cast(dchar)c);

            uint m = match(lexeme2);
            if (m == FULL_MATCH)
            {
                nextIsMatch = false;
                version(LexerDebug) writefln("FULL_MATCH for %s", lexeme2.str.data);
                
                if (lexeme1.str.data.length)
                {
                    auto res = lexeme1;
                    lexeme1 = lexeme2;
                    lexeme2 = emptyLexeme();
                    return res;
                }
                else
                {
                    auto res = lexeme2;
                    lexeme2 = emptyLexeme();
                    return res;
                }
            }
            else if (m == PARTIAL_MATCH)
            {
                version(LexerDebug) writefln("PARTIAL_MATCH for %s", lexeme2.str.data);
            }
            else if (m == CANDIDATE_MATCH)
            {
                version(LexerDebug) writefln("CANDIDATE_MATCH for %s", lexeme2.str.data);
                nextIsMatch = true;
            }
            else if (m == NO_MATCH)
            {
                version(LexerDebug) writefln("NO_MATCH for %s", lexeme2.str.data);

                if (nextIsMatch)
                {
                    version(LexerDebug) writeln("case 0");
                    nextIsMatch = false;
                    auto last = lexeme2.str.data[$-1];
                    lexeme2.str.remove(1);

                    if (lexeme1.str.data.length)
                    {
                        version(LexerDebug) writeln("case 1");
                        auto res = lexeme1;
                        lexeme1 = lexeme2;
                        lexeme2 = emptyLexeme();
                        initNextLexeme2 = last;
                        return res;
                    }
                    else
                    {
                        version(LexerDebug) writeln("case 2");
                        auto res = lexeme2;
                        lexeme2 = emptyLexeme();
                        initNextLexeme2 = last;
                        return res;
                    }
                }
                else
                {
                    version(LexerDebug) writeln("case 3");
                    lexeme1.str.append(lexeme2.str.data);
                    lexeme2.str.free();
                }
            }
        }

        auto res = lexeme1;
        if (lexeme2.str.data.length)
        {
            if (!res.str.data.length)
            {
                res = lexeme2;
            }
            else
            {
                lexeme1 = lexeme2;
            }
            lexeme2 = emptyLexeme();
        }
        else
        {
            lexeme1 = emptyLexeme();
        }

        if (!res.str.data.length)
            res.valid = false;

        return res;
    }

    uint match(Lexeme lexeme)
    {
        bool partialMatch = false;
        foreach(d; delimiters)
        {
            auto s = lexeme.str.data;
            size_t delimLen = 0;
            size_t matchedLen = 0;
            bool counting = true;
            foreach(i, c; d)
            {
                delimLen++;
                if (i < s.length)
                {
                    if (s[i] == c)
                    {
                        if (counting)
                            matchedLen++;
                    }
                    else
                        counting = false;
                }
            }
            if (matchedLen == delimLen && matchedLen == s.length)
            {
                if (!partialMatch)
                    return FULL_MATCH;
                else
                    return CANDIDATE_MATCH;
            }
            else if (matchedLen == s.length)
                partialMatch = true;
        }
        
        if (isWhite(lexeme.str.data[0]))
        {
            return FULL_MATCH;
        }

        if (partialMatch)
            return PARTIAL_MATCH;
        else
            return NO_MATCH;
    }
}

static string[] stddelimiters = 
[
    "==","!=","<=",">=","+=","-=","*=","/=",
    "++","--","||","&&","<<",">>","<>",
    "//","/*","*/","\\\\","\\\"","\\\'",
    "+","-","*","/","%","=","|","^","~","<",">","!",
    "(",")","{","}","[","]",
    ";",":",",","@","#","$","&",
    "\\","\"","\'"
];

struct StringFilter
{
    BaseFilter lexer;
    bool readingString = false;
    Lexeme strLexeme;
    dchar currentStrChar = 0;
    
    this(string str)
    {
        lexer = BaseFilter(str);
        lexer.delimiters = stddelimiters;
        sort!("a.length > b.length")(lexer.delimiters);
    }
    
    Lexeme get()
    {
        Lexeme lexeme;
        do
        {
            lexeme = lexer.get();
            if (lexeme.valid)
            {
                if (readingString)
                {
                    strLexeme.str.append(lexeme.str.data);
                }
                    
                if (isStringChar(lexeme))
                {
                    if (readingString)
                    {
                        readingString = false;
                        auto res = strLexeme;
                        strLexeme = emptyLexeme();
                        currentStrChar = 0;
                        return res;
                    }
                    else
                    {
                        currentStrChar = lexeme.str.data[0];
                        readingString = true;
                        strLexeme.str.append(lexeme.str.data);
                        continue;
                    }
                }
                else
                {
                    if (isWhite(lexeme.str.data[0]))
                    {
                        if (lexeme.str.data[0] == '\n')
                            return lexeme;
                        else
                            continue;
                    }
                    else
                    {
                        if (readingString)
                            continue;
                        else
                            return lexeme;
                    }
                }
            }
            else
                return lexeme;
        }
        while(lexeme.valid);
        return lexeme;
    }
    
    // TODO: support multi-char string marks
    bool isStringChar(Lexeme lexeme)
    {
        if (currentStrChar == 0)
            return 
                lexeme.str.data[0] == '"' ||
                lexeme.str.data[0] == '\'';
        else
            return lexeme.str.data[0] == currentStrChar;
    }

    uint line()
    {
        return lexer.line;
    }
}

// TODO: make this configurable
struct CommentFilter
{
    StringFilter lexer;
    bool readingComment = false;
    
    this(string str)
    {
        lexer = StringFilter(str);
    }
    
    Lexeme get()
    {
        Lexeme lexeme;
        do
        {
            lexeme = lexer.get();
            if (lexeme.valid)
            {
                if (lexeme.str.data[0] == '#')
                {
                    readingComment = true;
                    continue;
                }
                else
                {
                    if (lexeme.str.data[0] == '\n')
                    {
                        if (readingComment)
                            readingComment = false;
                        continue;
                    }
                    else
                    {
                        if (readingComment)
                            continue;
                        else
                            return lexeme;
                    }
                }
            }
            else
                return lexeme;
        }
        while(lexeme.valid);
        return lexeme;
    }

    uint line()
    {
        return lexer.line;
    }
}

struct Lexer
{
    CommentFilter lexer;
    Lexeme current;

    this(string str)
    {
        lexer = CommentFilter(str);
    }

    Lexeme get()
    {
        current = lexer.get();
        return current;
    }

    uint line()
    {
        return lexer.line;
    }
}

