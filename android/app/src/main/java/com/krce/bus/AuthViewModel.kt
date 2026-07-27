package com.krce.bus

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class AuthViewModel(private val savedStateHandle: SavedStateHandle) : ViewModel() {

    var authToken by mutableStateOf(savedStateHandle.get<String>("authToken") ?: "")
        private set

    var userRole by mutableStateOf(savedStateHandle.get<String>("userRole") ?: "")
        private set

    var userName by mutableStateOf(savedStateHandle.get<String>("userName") ?: "")
        private set

    var userBusId by mutableStateOf(savedStateHandle.get<String?>("userBusId"))
        private set

    var collegeId by mutableStateOf(savedStateHandle.get<String?>("collegeId"))
        private set

    var parentOf by mutableStateOf(savedStateHandle.get<String?>("parentOf"))
        private set

    var phone by mutableStateOf(savedStateHandle.get<String?>("phone"))
        private set

    var isDemoMode by mutableStateOf(savedStateHandle.get<Boolean>("isDemoMode") ?: false)

    fun setAuthState(
        token: String, 
        role: String, 
        name: String, 
        busId: String?, 
        demoMode: Boolean = false,
        cid: String? = null,
        pOf: String? = null,
        ph: String? = null
    ) {
        authToken = token
        userRole = role
        userName = name
        userBusId = busId
        collegeId = cid
        parentOf = pOf
        phone = ph
        isDemoMode = demoMode
        
        savedStateHandle["authToken"] = token
        savedStateHandle["userRole"] = role
        savedStateHandle["userName"] = name
        savedStateHandle["userBusId"] = busId
        savedStateHandle["collegeId"] = cid
        savedStateHandle["parentOf"] = pOf
        savedStateHandle["phone"] = ph
        savedStateHandle["isDemoMode"] = demoMode
    }

    fun logout() {
        authToken = ""
        userRole = ""
        userName = ""
        userBusId = null
        collegeId = null
        parentOf = null
        phone = null
        isDemoMode = false
        
        savedStateHandle.remove<String>("authToken")
        savedStateHandle.remove<String>("userRole")
        savedStateHandle.remove<String>("userName")
        savedStateHandle.remove<String?>("userBusId")
        savedStateHandle.remove<String?>("collegeId")
        savedStateHandle.remove<String?>("parentOf")
        savedStateHandle.remove<String?>("phone")
        savedStateHandle.remove<Boolean>("isDemoMode")
    }
}
