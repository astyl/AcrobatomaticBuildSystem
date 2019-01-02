#include <cppunit/extensions/HelperMacros.h>
#include <cppunit/plugin/TestPlugIn.h>
#include "BuildScriptTester/cpplib/Example.hpp"

using namespace BuildScriptTester::cpplib;

namespace test {

// ----------------------------------------------------------
// test fixture implementation
class TestExample: public CppUnit::TestFixture {
CPPUNIT_TEST_SUITE( TestExample );
CPPUNIT_TEST( testCaseSuccess );
CPPUNIT_CONDITIONAL_TEST( IS_INTERACTIVE , testCaseFail );
CPPUNIT_TEST_SUITE_END();

private:

public:
    void setUp() {
    }

    void tearDown() {
    }

    void testCaseSuccess() {
        std::cout << "in test case" << std::endl;
        CPPUNIT_ASSERT_EQUAL(1,1);
    }

    void testCaseFail() {
        CPPUNIT_ASSERT_EQUAL(0,1);
    }
};

CPPUNIT_TEST_SUITE_REGISTRATION(TestExample);
} // namespace test

