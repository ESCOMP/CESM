#include <iostream>
using namespace std;

class pioExampleClass {
public:
    pioExampleClass();
    ~pioExampleClass() {};
    void init ();
    //void write ();
    //void read ();
    //void read ();
};

pioExampleClass::pioExampleClass(){
    // user defined ctor with no arguments
    
    cout << " pioExampleClass::pioExampleClass() "<< endl;
    
}

void pioExampleClass::init () {
    
    cout << " pioExampleClass::init() " << endl;
    
}

int main () {
    
    pioExampleClass *pioExInst;
    
    pioExInst = new pioExampleClass();
    
    pioExInst->init();

    delete(pioExInst);
    
    return 0;
}