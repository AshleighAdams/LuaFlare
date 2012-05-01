#include "Configor.h"

#include <string>
#include <cstring>

using namespace std;

namespace ConfigorLexType
{
	const int None = 0;
	const int Token = 1;
	const int String = 2;
	const int NewLine = 3;
}

CConfigorNode::CConfigorNode(IConfigorNode* pParent, string Name)
{
	m_pParent = pParent;
	if(m_pParent)
		m_pParent->AddChild(this);
	m_Name = Name;
	m_pData = 0;
	m_Length = 0;
}

CConfigorNode::~CConfigorNode()
{
	// First we need to delete all of our children
	for(auto it = m_Children.begin(); it != m_Children.end(); it++)
	{
		IConfigorNode* node = *it;
		delete node;
	}
	// And then the data we hold
	DestroyData();
}

string CConfigorNode::GetName()
{
	return m_Name;
}

unsigned long CConfigorNode::GetDataLength()
{
	return m_Length;
}

unsigned char* CConfigorNode::GetData()
{
	return m_pData;
}

void CConfigorNode::DestroyData()
{
	if(m_pData)
		delete [] m_pData;
	m_pData = 0;
}

void CConfigorNode::SetData(unsigned char* pData, unsigned long Length)
{
	DestroyData();

	m_pData = new unsigned char[Length];
	m_Length = Length;

	memcpy(m_pData, pData, Length);
}

char* CConfigorNode::GetString()
{
	if(!m_pData)
	{
		char* r = new char[1];
		*r = 0;
		return r;
	}
	char* ret = new char[m_Length + 1];
	memcpy(ret, m_pData, m_Length);
	ret[m_Length] = 0;
	return ret;
}

IConfigorNode* CConfigorNode::GetChild(string Name)
{
	for(auto it = m_Children.begin(); it != m_Children.end(); it++)
		if((*it)->GetName() == Name)
			return *it;

	return 0;
}

IConfigorNodeList* CConfigorNode::GetChildren()
{
	return &m_Children;
}

IConfigorNode* CConfigorNode::GetParent()
{
	return m_pParent;
}

void CConfigorNode::AddChild(IConfigorNode* Node)
{
	m_Children.push_back(Node);
}

void CConfigorNode::RemoveChild(IConfigorNode* Node)
{
	m_Children.remove(Node);
	delete Node;
}

// Configor

char hex_map[256];
char hex_map_vv[256];

CConfigor::CConfigor()
{
	m_CurrentParseLine = 0;
	m_pRootNode = new CConfigorNode(0, "root");

#define SETMAP(x, y) hex_map[x] = y
	SETMAP('0', 0);
	SETMAP('1', 1);
	SETMAP('2', 2);
	SETMAP('3', 3);
	SETMAP('4', 4);
	SETMAP('5', 5);
	SETMAP('6', 6);
	SETMAP('7', 7);
	SETMAP('8', 8);
	SETMAP('9', 9);
	SETMAP('a', 10);
	SETMAP('b', 11);
	SETMAP('c', 12);
	SETMAP('d', 13);
	SETMAP('e', 14);
	SETMAP('f', 15);
	SETMAP('A', 10);
	SETMAP('B', 11);
	SETMAP('C', 12);
	SETMAP('D', 13);
	SETMAP('E', 14);
	SETMAP('F', 15);
#undef SETMAP
#define SETMAP(x, y) hex_map_vv[y] = x
	SETMAP('0', 0);
	SETMAP('1', 1);
	SETMAP('2', 2);
	SETMAP('3', 3);
	SETMAP('4', 4);
	SETMAP('5', 5);
	SETMAP('6', 6);
	SETMAP('7', 7);
	SETMAP('8', 8);
	SETMAP('9', 9);
	SETMAP('a', 10);
	SETMAP('b', 11);
	SETMAP('c', 12);
	SETMAP('d', 13);
	SETMAP('e', 14);
	SETMAP('f', 15);
	SETMAP('A', 10);
	SETMAP('B', 11);
	SETMAP('C', 12);
	SETMAP('D', 13);
	SETMAP('E', 14);
	SETMAP('F', 15);

#undef SETMAP
}

CConfigor::~CConfigor()
{
	delete m_pRootNode;
}

#include <fstream>

string CConfigor::GetError()
{
	return m_Error;
}

bool CConfigor::LoadFromFile(const std::string& Name)
{
	ifstream ifs(Name);

	if(!ifs.is_open())
	{
		m_Error = "File " + Name + " not found.";
		return false;
	}

	ifs.seekg(0, ios::end);
	unsigned long len = ifs.tellg();
	ifs.seekg(0, ios::beg);

	char* cnfg = new char[len];
	ifs.read(cnfg, len);
	ifs.close();

	bool ret = LoadFromString(cnfg, len);

	delete [] cnfg;

	return ret;
}

#include <sstream>


// Returns error!
string CConfigor::ParseQuotes(char** Out, unsigned long* Length, char* End)
{
	string sb;

	bool literal_ = false;
	bool hex_ = false;

	std::stringstream ss;

	do
	{
		char x = (char)*m_pCurrentParseChar;
		m_pCurrentParseChar++;

		if(hex_)
		{
			char a = x;
			char b = (char)*m_pCurrentParseChar;
			m_pCurrentParseChar++;

			unsigned char hx = (unsigned char)(hex_map[a] << 4) + (hex_map[b]);

			hex_ = false;
			sb += (char)hx;
			continue;
		}

		if(literal_)
		{
			switch(x)
			{
			case 't':
				sb+='\t';
				break;
			case 'n':
				sb+='\n';
				break;
			case 'r':
				sb+='\r';
				break;
			case 'b':
				sb+='\b';
				break;
			case 'x':
				hex_ = true;
				break;
			default:
				sb += x;
				break;
			}
			literal_ = false;
			continue;
		}else
		{
			switch(x)
			{
			case '\\':
				literal_ = true;
				break;
			case '"':
				goto EOL;
				break;
			case '\r':
			case '\n':
				{
					stringstream ss;
					ss << m_CurrentParseLine;
					return "Expected '\"' near line " + ss.str();
				}
				break;
			default:
				sb += x;
				break;
			}
		}
	}while(End != (char*)m_pCurrentParseChar);

	{
		std::stringstream out;
		out << m_CurrentParseLine;
		return "'\"' expected near line " + out.str();
	}
EOL:
	*Length = sb.size();
	*Out = new char[sb.size()];
	memcpy(*Out, sb.c_str(), sb.size());
	return "";
}

CConfigorLexNodeList CConfigor::Lexify(char* Input, unsigned long Length)
{
	CConfigorLexNodeList ret;
	m_CurrentParseLine = 1;

	m_pCurrentParseChar = (unsigned char*)Input;

	do
	{
		char x = *m_pCurrentParseChar;
		m_pCurrentParseChar++;

		switch(x)
		{
		case '"':
			{
				char* out;
				unsigned long len;
				string err = ParseQuotes(&out, &len, Input+Length);
				if(err.length() > 1)
				{
					CConfigorLexNode* node = new CConfigorLexNode;
					node->Type = ConfigorLexType::None;
					node->Error = err;
					node->Length = 0;
					ret.push_back(node);
					goto ENDLOOP;
				}
				else
				{
					CConfigorLexNode* node = new CConfigorLexNode;
					node->Type = ConfigorLexType::String;
					node->Value = out;
					node->Length = len;
					ret.push_back(node);
				}
			}
			break;
		case '{':
		case '}':
			{
				CConfigorLexNode* node = new CConfigorLexNode;
				node->Type = ConfigorLexType::Token;
				node->Value = (void*)x;
				node->Length = 0;
				ret.push_back(node);
			}
			break;
		case '\n':
			{
				m_CurrentParseLine++;
				CConfigorLexNode* node = new CConfigorLexNode;
				node->Type = ConfigorLexType::NewLine;
				node->Value = (void*)x;
				node->Length = 0;
				ret.push_back(node);
			}
			break;
		default:
			break;
		}

	}while(m_pCurrentParseChar != (unsigned char*)Input + Length);
ENDLOOP:
	return ret;
}

void PrintLexedNode(CConfigorLexNode* node)
{
	switch(node->Type)
	{
	case ConfigorLexType::None:
		printf("NONE/ERR:\t%s\n", node->Error.c_str());
		break;
	case ConfigorLexType::String:
		printf("STRING:\t%s\n", string((char*)node->Value, node->Length).c_str());
		break;
	case ConfigorLexType::Token:
		printf("TOKEN:\t%s\n", string((char*)&node->Value, 1).c_str());
		break;
	case ConfigorLexType::NewLine:
		printf("NEWLINE\n");
		break;
	}
}

bool CConfigor::LoadFromString(char* Input, unsigned long Length)
{
	CConfigorLexNodeList lexed = Lexify(Input, Length);

	/*
	for(auto n = lexed.begin(); n != lexed.end(); n++)
	{
		CConfigorLexNode* node = *n;
		PrintLexedNode(node);
	}
	*/

	unsigned int Depth = 0;
	m_CurrentParseLine = 1;

	IConfigorNode* pCurrentNode = GetRootNode();
	IConfigorNode* pNewNode = 0;

	for(auto it = lexed.begin(); it != lexed.end(); it++)
	{
		CConfigorLexNode* node = *it;
		switch(node->Type)
		{
		case ConfigorLexType::NewLine:
			m_CurrentParseLine++;
			break;
		case ConfigorLexType::None:
			{
				stringstream ss;
				ss << m_CurrentParseLine;
				m_Error = node->Error;
				return false;
			}
			break;
		case ConfigorLexType::String:
			{
				auto it2 = it;
				it2++;

				char* pName = (char*)node->Value;
				unsigned long mLength = node->Length;

				IConfigorNode* node = new CConfigorNode(pCurrentNode, string(pName, mLength));

				delete [] pName;

				if(it2 != lexed.end() || (*it2)->Type == ConfigorLexType::String)
				{
					it++;
					unsigned char* pData = (unsigned char*)(*it2)->Value;
					unsigned long dLength = (*it2)->Length;
					node->SetData(pData, dLength);
					if(dLength)
						delete [] pData;
					delete *it2; // Delete that node, we don't need it any more
				}

				pNewNode = node;
			}
			break;
		case ConfigorLexType::Token:
			{
				char Token = *(char*)&node->Value;

				switch(Token)
				{
				case '{':
					{
						if(!pNewNode) // We don't have a node to assign to!
						{
							stringstream ss;
							ss << m_CurrentParseLine;
							m_Error = "Node expected to group near line " + ss.str();
							return false;
						}
						Depth++;
						pCurrentNode = pNewNode;
						pNewNode = 0;
					}
					break;
				case '}':
					{
						pCurrentNode = pCurrentNode->GetParent();
						if(!pCurrentNode) // One too many }'s
						{
							stringstream ss;
							ss << m_CurrentParseLine;
							m_Error = "EOF expected near line " + ss.str();
							return false;
						}
						Depth--;
						pNewNode = 0;
					}
					break;
				default:
					m_Error = "Unexpected token " + Token;
				}
			}
			break;
		}

		// Free the node now
		delete node;
	}

	if(Depth)
	{
		m_Error = "Expected '}' near EOF";
		return false;
	}

	return true;
}

// Takes data + length, outputs char + length
void EscapeData(unsigned char* pData, unsigned long Length, unsigned char** Output, unsigned long* OutLength) 
{
	string sb;
	sb.reserve(Length);

	for(unsigned long i = 0; i < Length; i++)
	{
		char x = (char)pData[i];
		unsigned char ux = (unsigned char)x;

		if((ux >= 32 && ux <= 126) && x != '"')
			sb += x;
		else
		{
			switch(x)
			{
			case '"':
				sb += "\\\"";
				break;
			case '\n':
				sb += "\\n";
				break;
			case '\r':
				sb += "\\r";
				break;
			case '\t':
				sb += "\\t";
				break;
			case '\b':
				sb += "\\b";
				break;
			default:
				{
					unsigned char partb = x & 0x0F;
					unsigned char parta = (x & 0xF0) >> 4;
					sb += "\\x";
					sb += hex_map_vv[parta];
					sb += hex_map_vv[partb];
				}
			}
		}
	}

	*Output = new unsigned char[sb.size()];
	memcpy(*Output, sb.c_str(), sb.size());
	*OutLength = sb.size();
}

#define DODEPTH for(int i = 0; i < Depth; i++)\
		ofs << '\t'

void RecursiveSave(ofstream& ofs, IConfigorNode* node, int Depth = 0)
{
	unsigned char* pData;
	unsigned long Length;

	EscapeData((unsigned char*)node->GetName().c_str(), node->GetName().size(), &pData, &Length);

	DODEPTH;
	
	ofs << '"';
	ofs.write((const char*)pData, Length);
	ofs << '"';

	delete [] pData;

	if(node->GetData() && node->GetDataLength() != 0)
	{
		EscapeData(node->GetData(), node->GetDataLength(), &pData, &Length);
		ofs << " \"";
		ofs.write((const char*)pData, Length);
		ofs << '"';
		delete [] pData;
	}

	ofs << '\n';

	IConfigorNodeList* lst = node->GetChildren();
	if(lst->begin() != lst->end())
	{
		DODEPTH;
		ofs << "{\n";

		for(auto it = lst->begin(); it != lst->end(); it++)
			RecursiveSave(ofs, *it, Depth + 1);

		DODEPTH;
		ofs << "}\n";
	}
}

#include <ctype.h>

bool CConfigor::SaveToFile(const std::string& Name)
{
	ofstream ofs(Name);

	if(!ofs.is_open())
		return false;

	IConfigorNodeList* lst = GetRootNode()->GetChildren();
	if(lst->begin() != lst->end())
		for(auto it = lst->begin(); it != lst->end(); it++)
			RecursiveSave(ofs, *it);

	return true;
}

IConfigorNode* CConfigor::GetRootNode()
{
	return m_pRootNode;
}

IConfigorNode& CConfigor::operator[](const std::string& Index)
{
	IConfigorNode* n = GetRootNode()->GetChild(Index);
	if(!n)
		n = new CConfigorNode(GetRootNode(), Index);
	return *n;
}

IConfigorNode& CConfigorNode::operator[](const std::string& Index)
{
	IConfigorNode* n = GetChild(Index);
	if(!n)
		n = new CConfigorNode(this, Index);
	return *n;
}

void CConfigorNode::operator=(char* pData)
{
	SetData((unsigned char*)pData, strlen(pData));
}
