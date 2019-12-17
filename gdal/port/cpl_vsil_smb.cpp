/**********************************************************************
 *
 * Project:  CPL - Common Portability Library
 * Purpose:  Implement VSI large file api for SMB
 * Author:   Craig de Stigter, <craig@destigter.nz>
 *
 **********************************************************************
 * Copyright (c) 2010-2015, Even Rouault <even dot rouault at mines-paris dot org>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 ****************************************************************************/

//! @cond Doxygen_Suppress

#include <string>

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#if !defined(_MSC_VER)
#include <unistd.h>
#endif

#include <cstring>
#include <climits>

#include "cpl_port.h"
#include "cpl_vsi.h"

#include "cpl_conv.h"
#include "cpl_error.h"
#include "cpl_vsi_virtual.h"

CPL_CVSID("$Id$")

#ifdef SMB_ENABLED

#include "libsmbclient.h"


#ifndef DOXYGEN_SKIP
class CPL_DLL VSISmbFilesystemHandler final : public VSIFilesystemHandler {

public:
    VSISmbFilesystemHandler() = default;
    ~VSISmbFilesystemHandler() = default;

    VSIVirtualHandle *Open( const char *pszFilename,
                            const char *pszAccess ) override;

    CPLString GetFSPrefix() override { return "/vsismb/"; }
    const char* GetDebugKey() const override { return "SMB"; }

    virtual VSIVirtualHandle *Open( const char *pszFilename,
                                    const char *pszAccess,
                                    bool bSetError ) override;
    virtual int Stat( const char *pszFilename, VSIStatBufL *pStatBuf, int nFlags) override;
    virtual int Unlink( const char *pszFilename ) override;
    virtual int Mkdir( const char *pszDirname, long nMode ) override;
    virtual int Rmdir( const char *pszDirname ) override;
    virtual char **ReadDir( const char *pszDirname ) override;
    virtual char **ReadDirEx( const char *pszDirname, int /* nMaxFiles */ ) override;
    virtual int Rename( const char *oldpath, const char *newpath ) override;

    virtual VSIDIR* OpenDir( const char *pszPath, int nRecurseDepth,
                             const char* const *papszOptions) override;
};

/************************************************************************/
/* ==================================================================== */
/*                        VSISmbHandle                               */
/* ==================================================================== */
/************************************************************************/


class VSISmbHandle final : public VSIVirtualHandle
{
  private:
    CPL_DISALLOW_COPY_ASSIGN(VSISmbHandle)

    SMBCCTX poCtx = nullptr;
    SMBCFILE poFile = nullptr;
    std::string oFilename;
    bool bEOF = false;

  public:
#if __cplusplus >= 201103L
     static constexpr const char * VSISMB = "/vsismb/";
#else
     static const char * VSISMB = "/vsismb/";
#endif
     VSISmbHandle(SMBCCTX poCtx,
                   SMBCFILE poFile,
                   const char * pszFilename);
    ~VSISmbHandle() override;

    int Seek(vsi_l_offset nOffset, int nWhence) override;
    vsi_l_offset Tell() override;
    size_t Read(void *pBuffer, size_t nSize, size_t nMemb) override;
    size_t Write(const void *pBuffer, size_t nSize, size_t nMemb) override;
    vsi_l_offset Length();
    int Eof() override;
    int Flush() override;
    int Close() override;
};


/************************************************************************/
/*                       VSIInstallSmbHandler()                        */
/************************************************************************/

/**
 * \brief Install /vsismb/ file system handler (requires libsmbclient)
 *
 */
void VSIInstallSmbHandler()
{
    VSIFileManager::InstallHandler(VSISmbHandle::VSISMB, new VSISmbFilesystemHandler);
}

#else

/************************************************************************/
/*                       VSIInstallSmbHandler()                        */
/************************************************************************/

/**
 * \brief Install /vsismb/ file system handler (non-functional stub)
 *
 */
void VSIInstallSmbHandler( void )
{
    // Not supported.
}

#endif
