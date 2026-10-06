#ifndef COA_PORTABLE_IMPORT_H
#define COA_PORTABLE_IMPORT_H

#include "Define.h"
#include <string>

namespace CoAPortableImport
{
    bool ValidJobId(std::string const& text);
    std::string Run(std::string const& jobId);
}

#endif
